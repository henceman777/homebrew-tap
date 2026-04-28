class Meetap < Formula
  desc "macOS meeting recorder with auto-transcription and AI meeting notes"
  homepage "https://github.com/henceman777/meetap"
  url "https://github.com/henceman777/meetap/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "7eeeb6146156e629f2a6ac46fea38dd829ad5f12625555e16bdcc0606a16165c"
  license "MIT"

  depends_on :macos
  depends_on "ffmpeg"
  depends_on "switchaudio-osx"
  depends_on "python@3"

  def install
    odie "Xcode Command Line Tools required: xcode-select --install" unless which("swiftc")

    system "swiftc", "-O",
           "-framework", "CoreAudio",
           "-framework", "AudioToolbox",
           "src/audio-multi-output.swift",
           "-o", buildpath/"audio-multi-output"

    system "swiftc", "-O",
           "-framework", "CoreAudio",
           "-framework", "AudioToolbox",
           "src/audio-monitor.swift",
           "-o", buildpath/"audio-monitor"

    bin.install "src/meetap"
    bin.install buildpath/"audio-multi-output"
    bin.install buildpath/"audio-monitor"

    (etc/"meetap").mkpath
    (etc/"meetap").install "config.default"

    venv = libexec/"meetap-venv"
    system "python3", "-m", "venv", "--system-site-packages", venv.to_s
    system venv/"bin/pip", "install", "-q", "--timeout", "30", "boto3"
    bin.install_symlink venv => "meetap-venv"
  end

  def post_install
    unless system("brew", "list", "--cask", "blackhole-2ch", out: File::NULL, err: File::NULL)
      ohai "Installing BlackHole 2ch (virtual audio driver)..."
      system "brew", "install", "--cask", "blackhole-2ch"
    end
    ohai "Restarting Core Audio to detect BlackHole..."
    unless system("sudo", "killall", "coreaudiod")
      opoo "Could not restart coreaudiod. If BlackHole is not detected, run: sudo killall coreaudiod"
    end
    sleep 3
  end

  def caveats
    <<~EOS
      AWS CLI must be configured with Transcribe + Bedrock permissions:

        aws configure

      Initialize your config:

        meetap config init

      Default config template: #{etc}/meetap/config.default
    EOS
  end

  test do
    assert_match "MeeTap v", shell_output("#{bin}/meetap version")
  end
end
