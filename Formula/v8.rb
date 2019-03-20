# Track Chrome stable, see https://omahaproxy.appspot.com/
class V8 < Formula
  desc "Google's JavaScript engine"
  homepage "https://github.com/v8/v8/wiki"
  url "https://chromium.googlesource.com/chromium/tools/depot_tools.git",
      :revision => "5637e87bda2811565c3e4e58bd2274aeb3a4757e"
  version "7.3.492.25" # the version of the v8 checkout, not a depot_tools version

  bottle do
    cellar :any
    sha256 "3c5a20cfa14742c57ec0827a82a940ce926d0fb6b399211d008cdb082c9c1efb" => :mojave
    sha256 "4e24541ca043f3ce01757833a506965c44a7b41e215e209c17d53b6305146e4a" => :high_sierra
    sha256 "2e82dfdf851764acf2d514091ecd5cb101aa10410efa276ff2725225759cd09a" => :sierra
  end

  # depot_tools/GN require Python 2.7+
  depends_on "python@2" => :build

  # https://bugs.chromium.org/p/chromium/issues/detail?id=620127
  depends_on :macos => :el_capitan

  def install
    # Add depot_tools in PATH
    ENV.prepend_path "PATH", buildpath
    # Prevent from updating depot_tools on every call
    # see https://www.chromium.org/developers/how-tos/depottools#TOC-Disabling-auto-update
    ENV["DEPOT_TOOLS_UPDATE"] = "0"

    # Initialize and sync gclient
    system "gclient", "root"
    system "gclient", "config", "--spec", <<~EOS
      solutions = [
        {
          "url": "https://chromium.googlesource.com/v8/v8.git",
          "managed": False,
          "name": "v8",
          "deps_file": "DEPS",
          "custom_deps": {},
        },
      ]
      target_os = [ "mac" ]
      target_os_only = True
      cache_dir = "#{HOMEBREW_CACHE}/gclient_cache"
    EOS

    system "gclient", "sync",
      "-j", ENV.make_jobs,
      "-r", version,
      "--no-history",
      "-vvv"

    # Enter the v8 checkout
    cd "v8" do
      gn_args = {
        :is_debug                     => false,
        :is_component_build           => true,
        :v8_use_external_startup_data => false,
        :v8_enable_i18n_support       => true,
      }

      # Transform to args string
      gn_args_string = gn_args.map { |k, v| "#{k}=#{v}" }.join(" ")

      # Build with gn + ninja
      system "gn", "gen", "--args=#{gn_args_string}", "out.gn"
      system "ninja", "-j", ENV.make_jobs, "-C", "out.gn", "-v", "d8"

      # Install all the things
      (libexec/"include").install Dir["include/*"]
      libexec.install Dir["out.gn/lib*.dylib", "out.gn/d8", "out.gn/icudtl.dat"]
      bin.write_exec_script libexec/"d8"
    end
  end

  test do
    assert_equal "Hello World!", shell_output("#{bin}/d8 -e 'print(\"Hello World!\");'").chomp
    t = "#{bin}/d8 -e 'print(new Intl.DateTimeFormat(\"en-US\").format(new Date(\"2012-12-20T03:00:00\")));'"
    assert_match %r{12/\d{2}/2012}, shell_output(t).chomp
  end
end
