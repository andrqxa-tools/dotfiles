# Flutter / Android toolchain (mabrook)

Installs everything needed to build and run the mabrook Flutter projects
(`minitok_clean`, `wallet-front/example`) on Android, on a fresh Ubuntu 24.04
machine.

## What it installs

- **JDK 17** (`openjdk-17-jdk`) — the Gradle/Kotlin toolchain is pinned to Java 17.
- **Android SDK** — cmdline-tools, platform-tools/adb, platforms 35+36,
  build-tools 35/36, NDK `28.2.13676358`.
- **FVM + Flutter 3.38.5** — the version pinned in both projects' `.fvmrc`.
- *(optional, `--emulator`)* — system image API 34 + a `pixel_6` AVD, and adds
  the user to the `kvm` group for hardware acceleration.

Project requirements: `compileSdk 36 · targetSdk 35 · minSdk 26 · NDK 28.2 · Java 17`.

## Disk layout (this workstation)

The system SSD (`/`) is small, so the heavy bits go to the `/data` HDD:

| Piece | Location | Why |
|-------|----------|-----|
| Android SDK | `/data/Android/Sdk` | NDK ~2.5 GB + platforms + emulator image |
| FVM version cache | `/data/Android/fvm` | each Flutter version ~1.7 GB |
| Emulator AVD | `~/.android/avd` (SSD) | kept on SSD so the emulator stays responsive |

Override with `ANDROID_SDK_DIR=... FVM_CACHE_PATH=...` — and keep
`../Shell/profile.d/flutter.sh` in sync if you do.

## Usage

```sh
# env for every shell (login/non-login/GUI/tmux) — symlink into the profile.d loader
ln -sf "$PWD/Shell/profile.d/flutter.sh" ~/.config/profile.d/flutter.sh

# install the toolchain (the script also creates the symlink above)
./Flutter/setup-android-env.sh            # JDK17 + Android SDK + FVM/Flutter
./Flutter/setup-android-env.sh --emulator # + system image, AVD, kvm group
./Flutter/setup-android-env.sh --no-fvm   # skip FVM/Flutter

source ~/.config/profile.d/flutter.sh     # or re-login
```

The script is idempotent and uses `sudo` only for `apt` and `usermod -aG kvm`.
After `--emulator` you must **re-login** for the `kvm` group to take effect.
