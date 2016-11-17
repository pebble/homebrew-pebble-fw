require 'formula'

class Freetype < Formula
  homepage 'http://www.freetype.org'
  url 'http://download.savannah.gnu.org/releases/freetype/freetype-2.4.11.tar.bz2'
  sha256 'ef9d0bcb64647d9e5125dc7534d7ca371c98310fec87677c410f397f71ffbe3f'

  keg_only :provided_pre_mountain_lion

  option :universal

  def install
    ENV.universal_binary if build.universal?
    system "./configure", "--prefix=#{prefix}"
    system "make install"
  end

  test do
    system "#{bin}/freetype-config", '--cflags', '--libs', '--ftversion',
      '--exec-prefix', '--prefix'
  end
end
