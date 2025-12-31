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
, imagemagick
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
      
      # PATCH 1: Remove unnecessary internet check that blocks LAN sync
      sed -i 's/urllib.request.urlopen.*google.com.*timeout=5.*/pass  # Internet check removed by NixOS patch/' "$APP_DIR/main.py"
      
      # PATCH 2: Fix server socket - use sendall() instead of send() for reliable transfer
      sed -i 's/client_socket\.send(headers\.encode())/client_socket.sendall(headers.encode())/' "$APP_DIR/main.py"
      sed -i 's/client_socket\.send(data)/client_socket.sendall(data)/' "$APP_DIR/main.py"
      
      # PATCH 3: Increase chunk size from 4096 to 65536 for faster transfer
      sed -i 's/f\.read(4096)/f.read(65536)/' "$APP_DIR/main.py"
      
      # PATCH 4: Add debug output - print when client connects
      sed -i 's/def handle_client(self, client_socket):/def handle_client(self, client_socket):\n        print(f"[DEBUG] Client connected: {client_socket.getpeername()}")/' "$APP_DIR/main.py"
      
      # PATCH 5: Add debug output - print request received
      sed -i 's/request = client_socket.recv(1024)/request = client_socket.recv(1024)\n            print(f"[DEBUG] Received request: {request[:100]}")/' "$APP_DIR/main.py"
      
      # PATCH 6: Add debug output - print file sending
      sed -i 's/file_size = os.path.getsize/print(f"[DEBUG] Sending temp.zip...")\n            file_size = os.path.getsize/' "$APP_DIR/main.py"
      
      echo "Applied NixOS patches to main.py (internet check, sendall, chunk size, debug)"
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

  nativeBuildInputs = [ copyDesktopItems imagemagick ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin $out/share/nx-save-sync
    
    # Copy the FHS wrapper
    cp ${fhsEnv}/bin/nx-save-sync $out/bin/
    
    # Copy source for reference
    cp -r desktop $out/share/nx-save-sync/
    
    # Install icon - convert ico to png for proper Linux support
    mkdir -p $out/share/icons/hicolor/256x256/apps
    mkdir -p $out/share/icons/hicolor/128x128/apps
    mkdir -p $out/share/icons/hicolor/64x64/apps
    mkdir -p $out/share/icons/hicolor/48x48/apps
    
    # Convert ico to png (ico files contain multiple sizes)
    magick desktop/include/icon.ico -resize 256x256 $out/share/icons/hicolor/256x256/apps/nx-save-sync.png || \
      convert desktop/include/icon.ico[0] $out/share/icons/hicolor/256x256/apps/nx-save-sync.png || true
    magick desktop/include/icon.ico -resize 128x128 $out/share/icons/hicolor/128x128/apps/nx-save-sync.png || true
    magick desktop/include/icon.ico -resize 64x64 $out/share/icons/hicolor/64x64/apps/nx-save-sync.png || true
    magick desktop/include/icon.ico -resize 48x48 $out/share/icons/hicolor/48x48/apps/nx-save-sync.png || true
    
    runHook postInstall
  '';

  desktopItems = [ desktopItem ];

  meta = fhsEnv.meta;
}
