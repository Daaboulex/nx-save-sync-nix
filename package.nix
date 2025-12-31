# NX-Save-Sync Package for NixOS
# Switch save sync tool - desktop Linux version
# Uses buildFHSEnv because dearpygui and keyboard aren't in nixpkgs
{ lib
, stdenv
, fetchFromGitHub
, buildFHSEnv
, python3
, makeDesktopItem
, copyDesktopItems
, writeShellScript
}:

let
  # Auto-updated by GitHub Actions
  version = "2.3.0";

  # The source
  src = fetchFromGitHub {
    owner = "Xc987";
    repo = "NX-Save-Sync";
    rev = version;
    hash = "sha256-VQfBxKtUUe1RTFyDQIgVKZHtdOEpsaVouTw12GXFzWg=";
  };

  # Desktop item
  desktopItem = makeDesktopItem {
    name = "nx-save-sync";
    exec = "nx-save-sync";
    icon = "nx-save-sync";
    desktopName = "NX Save Sync";
    comment = "Sync Nintendo Switch saves with emulators";
    categories = [ "Game" "Utility" ];
  };

  # First run setup script
  setupScript = writeShellScript "nx-save-sync-setup" ''
    VENV_DIR="$HOME/.local/share/nx-save-sync/venv"
    APP_DIR="$HOME/.local/share/nx-save-sync/app"
    
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
      echo "First run: Setting up NX-Save-Sync..."
      mkdir -p "$VENV_DIR" "$APP_DIR"
      python3 -m venv "$VENV_DIR"
      source "$VENV_DIR/bin/activate"
      pip install --upgrade pip
      pip install dearpygui requests keyboard pynput
      # Install patched pynput for xorg fix (as per upstream build docs)
      pip install git+https://github.com/maddinpsy/pynput.git@fixup-xorg-merge-artifact || true
      deactivate
      echo "Setup complete!"
    fi
    
    # Copy/update app files (handle Nix store read-only files)
    if [ ! -f "$APP_DIR/main.py" ] || [ "@src@/desktop/main.py" -nt "$APP_DIR/main.py" ]; then
      rm -rf "$APP_DIR"/* 2>/dev/null || true
      chmod -R u+w "$APP_DIR" 2>/dev/null || true
      cp -r @src@/desktop/* "$APP_DIR/"
      chmod -R u+w "$APP_DIR"
    fi
    
    # Run the app with environment fixes
    source "$VENV_DIR/bin/activate"
    cd "$APP_DIR"
    
    # Show local IP for Switch connection
    echo "=== Your PC IP address(es) for Switch connection ==="
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127' || hostname -I | tr ' ' '\n' | head -3
    echo "==================================================="
    
    # Fix window positioning on Wayland (force Xwayland if needed)
    export QT_QPA_PLATFORM=xcb 2>/dev/null || true
    export GDK_BACKEND=x11 2>/dev/null || true
    
    exec python3 main.py "$@"
  '';

  # FHS environment for running the app
  fhsEnv = buildFHSEnv {
    name = "nx-save-sync";
    targetPkgs = pkgs: with pkgs; [
      python3
      python3Packages.pip
      python3Packages.virtualenv
      
      # For building evdev (pynput dependency)
      gcc
      gnumake
      linuxHeaders
      git
      
      # Graphics/GUI deps for dearpygui
      libGL
      libxkbcommon
      xorg.libX11
      xorg.libXcursor
      xorg.libXrandr
      xorg.libXinerama
      xorg.libXi
      xorg.libXext
      xorg.libXfixes
      wayland
      
      # For keyboard/pynput module
      xorg.libXtst
    ];

    runScript = builtins.replaceStrings ["@src@"] ["${src}"] (builtins.readFile setupScript);
    
    meta = with lib; {
      description = "Switch homebrew app to sync save files between console and emulator";
      homepage = "https://github.com/Xc987/NX-Save-Sync";
      license = licenses.gpl3Only;
      maintainers = [ ];
      platforms = platforms.linux;
      mainProgram = "nx-save-sync";
    };
  };

in stdenv.mkDerivation {
  pname = "nx-save-sync";
  inherit version src;

  nativeBuildInputs = [ copyDesktopItems ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin $out/share/nx-save-sync
    
    # Copy the FHS wrapper
    cp ${fhsEnv}/bin/nx-save-sync $out/bin/
    
    # Copy source for reference
    cp -r desktop $out/share/nx-save-sync/
    
    # Install icon
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp desktop/include/icon.ico $out/share/icons/hicolor/256x256/apps/nx-save-sync.ico 2>/dev/null || true
    
    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  meta = fhsEnv.meta;
}
