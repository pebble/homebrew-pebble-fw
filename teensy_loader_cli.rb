require 'formula'

class TeensyLoaderCli < Formula
  homepage "https://github.com/pebble/qemu"
  url "git@github.com:pebble/teensy_loader_cli.git", :branch => "mac_libusb", :using => :git

  def install
    system 'make'
    bin.install 'teensy_loader_cli'
  end
end
