class Meetap < Formula
  desc "macOS meeting recorder with auto-transcription and AI meeting notes"
  homepage "https://github.com/henceman777/meetap"
  url "https://github.com/henceman777/meetap/archive/refs/tags/v1.7.2.tar.gz"
  sha256 "130c62a024947d752778c8244dcf483bbd57f4c1e22a0c7e3ad008c0224d6df1"
  license "MIT"

  depends_on "ffmpeg"
  # Homebrew 只能按大版本限制（Sonoma = 14.x）；meetap 2.0 需要 14.4+，由 meetap start / setup 运行时检查
  depends_on macos: :sonoma
  depends_on "python@3"

  def install
    odie "Xcode Command Line Tools required: xcode-select --install" unless which("swiftc")

    # audio-multi-output 嵌入 Info.plist（日历用途说明），否则 EventKit 不让读日历
    system "swiftc", "-O",
           "-framework", "CoreAudio",
           "-framework", "AudioToolbox",
           "-framework", "IOKit",
           "-framework", "EventKit",
           "-Xlinker", "-sectcreate",
           "-Xlinker", "__TEXT",
           "-Xlinker", "__info_plist",
           "-Xlinker", "src/audio-multi-output-Info.plist",
           "src/audio-multi-output.swift",
           "-o", buildpath/"audio-multi-output"

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
    bin.install buildpath/"audio-tap"

    # bin.install 复制会破坏 ad-hoc 签名（带 __info_plist 段尤甚），TCC 判定签名
    # 无效后内核会在创建 Process Tap 时 SIGKILL 进程。安装后必须重新签名。
    system "codesign", "--force", "--sign", "-", bin/"audio-tap"
    system "codesign", "--force", "--sign", "-", bin/"audio-multi-output"

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

      Requires macOS 14.4 or later. MeeTap captures audio with the built-in
      Core Audio Process Tap — no virtual audio driver needed. Run the one-time
      check before your first meeting:

        meetap setup

      It verifies the "System Audio Recording" permission (and guides you
      through granting it), and after upgrading from 1.x checks whether system
      output or meeting apps still point at BlackHole.

      Upgrading from 1.x: BlackHole is no longer used. You may uninstall it if
      nothing else needs it (optional):

        brew uninstall --cask blackhole-2ch

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
