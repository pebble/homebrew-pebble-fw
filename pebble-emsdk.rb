class PebbleEmsdk < Formula
  desc ""
  homepage "http://emscripten.org"
  url "https://s3.amazonaws.com/mozilla-games/emscripten/releases/emsdk-portable.tar.gz"
  version "portable"
  sha256 "39114f25e1b3f4d1e15dc8d8f59227c30be855e79cbff91fbf2e3f31f7bb2cd1"

  def install
    system "./emsdk", "update"
    system "./emsdk", "install", "emscripten-1.35.0"
    system "./emsdk", "install", "clang-e1.35.0-64bit"
    system "./emsdk", "install", "node-4.1.1-64bit"

    prefix.install Dir["*"]
  end

  test do
    system "emcc", "--version"
  end
end
