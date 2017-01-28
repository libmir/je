class Je < Formula
  desc "Fast JSON to TSV/CSV/JSON Extractor"
  homepage "https://github.com/tamediadigital/je"
  url "https://github.com/tamediadigital/je/archive/v0.0.0.tar.gz"
  sha256 "1400063bc4f70bd532d42a664f25244a6517c6fd135ec2c0a73c96437795db9d"
  head "https://github.com/tamediadigital/je.git"

  depends_on "dub" => :build
  depends_on "ldc" => [:build, "developer"]

  def install
    compiler = "ldmd2"
    system "dub", "build", "--compiler=" + compiler, "--build=release-native"
    bin.install "je"
  end
end
