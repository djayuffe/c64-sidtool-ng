#!/usr/bin/env ruby
# frozen_string_literal: true

# Creates a minimal PSID v2 tune for the README examples. The init routine
# opens a triangle-wave SID voice at $1000; the play routine returns.
output_path = File.expand_path('minimal-tone.sid', __dir__)
init = [0xa9, 0x00, 0x8d, 0x00, 0xd4,
        0xa9, 0x10, 0x8d, 0x01, 0xd4,
        0xa9, 0x11, 0x8d, 0x04, 0xd4,
        0xa9, 0x00, 0x8d, 0x05, 0xd4,
        0xa9, 0xf0, 0x8d, 0x06, 0xd4, 0x60]
play_address = 0x1000 + init.length

header = +'PSID'
header << [2, 0x7c, 0, 0x1000, play_address, 1, 1].pack('n7')
header << [0].pack('N')
header << 'SIDtool minimal tone'.ljust(32, "\0")
header << 'C64 SIDtool NG'.ljust(32, "\0")
header << 'Example'.ljust(32, "\0")
header << ("\0" * (0x7c - header.bytesize))

File.binwrite(output_path, header + ([0x00, 0x10] + init + [0x60]).pack('C*'))
puts "Wrote #{output_path}"
