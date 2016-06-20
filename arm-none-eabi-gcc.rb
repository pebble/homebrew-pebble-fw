class ArmNoneEabiGcc < Formula
  homepage "https://launchpad.net/gcc-arm-embedded"
  version "20150921"
  url "https://launchpad.net/gcc-arm-embedded/4.9/4.9-2015-q3-update/+download/gcc-arm-none-eabi-4_9-2015q3-20150921-mac.tar.bz2"
  sha256 "a6353db31face60c2091c2c84c902fc4d566decd1aa04884cd822c383d13c9fa"

  def install
    prefix.install 'arm-none-eabi', 'bin', 'lib', 'share'
    system 'mv', "#{bin}/arm-none-eabi-gdb", "#{bin}/arm-none-eabi-gdb-no-py"
    system 'mv', "#{bin}/arm-none-eabi-gdb-py", "#{bin}/arm-none-eabi-gdb"
  end
end

