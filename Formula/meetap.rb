class Meetap < Formula
  desc "macOS meeting recorder with auto-transcription and AI meeting notes"
  homepage "https://github.com/henceman777/meetap"
  url "https://github.com/henceman777/meetap/archive/refs/tags/v1.6.1.tar.gz"
  sha256 "6427a2814af65cb2623d452283fdb643a05ae55521913dcaf445234cfe2c940a"
  license "MIT"

  depends_on "ffmpeg"
  depends_on :macos
  depends_on "python@3"
  depends_on "switchaudio-osx"

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

    # audio-tap 必须嵌入 Info.plist（NSAudioCaptureUsageDescription），否则 TCC
    # 不弹授权框、静默拒绝，Process Tap 输出全零静音（macOS 14.4+ 主采集路径）。
    system "swiftc", "-O",
           "-framework", "CoreAudio",
           "-framework", "AudioToolbox",
           "-Xlinker", "-sectcreate",
           "-Xlinker", "__TEXT",
           "-Xlinker", "__info_plist",
           "-Xlinker", "src/audio-tap-Info.plist",
           "src/audio-tap.swift",
           "-o", buildpath/"audio-tap"

    bin.install "src/meetap"
    bin.install buildpath/"audio-multi-output"
    bin.install buildpath/"audio-monitor"
    bin.install buildpath/"audio-tap"

    # bin.install 复制会破坏 ad-hoc 签名（带 __info_plist 段尤甚），TCC 判定签名
    # 无效后内核会在创建 Process Tap 时 SIGKILL 进程。安装后必须重新签名。
    system "codesign", "--force", "--sign", "-", bin/"audio-tap"

    # meetap 通过 SCRIPT_DIR/../src/lib/ui.sh 加载终端 UI 辅助脚本
    (prefix/"src/lib").install "src/lib/ui.sh"

    # CLI 双语消息表（load_i18n 需要）
    (share/"meetap/i18n").install Dir["src/i18n/*.sh"]

    # 纪要提示词模板 + 邮件 HTML 模板
    (share/"meetap/prompts").install Dir["share/meetap/prompts/*.md"]
    (share/"meetap/templates").install Dir["share/meetap/templates/*.html"]

    # 首次运行时 ensure_config 拷贝的默认配置模板
    (share/"meetap").install "config.default"

    # Python venv：纪要生成（boto3）+ 邮件 Markdown 渲染（markdown）
    venv = libexec/"meetap-venv"
    system "python3", "-m", "venv", "--system-site-packages", venv.to_s
    system venv/"bin/pip", "install", "-q", "--timeout", "60", "boto3==1.40.0", "markdown"
    bin.install_symlink venv => "meetap-venv"
  end

  def caveats
    <<~EOS
      AWS CLI must be configured with Transcribe + Bedrock permissions:

        aws configure

      Audio capture (macOS 14.4+): MeeTap uses Core Audio Process Tap by
      default — no virtual audio driver needed. Run the one-time permission
      check before your first meeting:

        meetap setup

      This verifies the "System Audio Recording" permission and guides you
      through granting it if needed.

      Older macOS (13.x) falls back to the BlackHole virtual driver. Install
      it only if you are on 13.x or set audio_capture=blackhole:

        brew install blackhole-2ch
        sudo killall coreaudiod      # let the system detect it

      A default config is auto-created at ~/.config/meetap/config on first
      run. Edit it any time with:

        meetap config          # opens $EDITOR
        meetap config show     # prints current values
    EOS
  end

  test do
    assert_match "MeeTap v", shell_output("#{bin}/meetap version")
  end
end
