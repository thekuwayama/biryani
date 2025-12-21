module Biryani
  module HPACK
    # https://datatracker.ietf.org/doc/html/rfc7541#appendix-A
    STATIC_TABLE = [
      [':authority',                  ''],
      [':method',                     'GET'],
      [':method',                     'POST'],
      [':path',                       '/'],
      [':path',                       '/index.html'],
      [':scheme',                     'http'],
      [':scheme',                     'https'],
      [':status',                     '200'],
      [':status',                     '204'],
      [':status',                     '206'],
      [':status',                     '304'],
      [':status',                     '400'],
      [':status',                     '404'],
      [':status',                     '500'],
      ['accept-charset',              ''],
      ['accept-encoding',             'gzip, deflate'],
      ['accept-language',             ''],
      ['accept-ranges',               ''],
      ['accept',                      ''],
      ['access-control-allow-origin', ''],
      ['age',                         ''],
      ['allow',                       ''],
      ['authorization',               ''],
      ['cache-control',               ''],
      ['content-disposition',         ''],
      ['content-encoding',            ''],
      ['content-language',            ''],
      ['content-length',              ''],
      ['content-location',            ''],
      ['content-range',               ''],
      ['content-type',                ''],
      ['cookie',                      ''],
      ['date',                        ''],
      ['etag',                        ''],
      ['expect',                      ''],
      ['expires',                     ''],
      ['from',                        ''],
      ['host',                        ''],
      ['if-match',                    ''],
      ['if-modified-since',           ''],
      ['if-none-match',               ''],
      ['if-range',                    ''],
      ['if-unmodified-since',         ''],
      ['last-modified',               ''],
      ['link',                        ''],
      ['location',                    ''],
      ['max-forwards',                ''],
      ['proxy-authenticate',          ''],
      ['proxy-authorization',         ''],
      ['range',                       ''],
      ['referer',                     ''],
      ['refresh',                     ''],
      ['retry-after',                 ''],
      ['server',                      ''],
      ['set-cookie',                  ''],
      ['strict-transport-security',   ''],
      ['transfer-encoding',           ''],
      ['user-agent',                  ''],
      ['vary',                        ''],
      ['via',                         ''],
      ['www-authenticate',            '']
    ].freeze
    STATIC_TABLE_SIZE = STATIC_TABLE.length

    private_constant :STATIC_TABLE, :STATIC_TABLE_SIZE
    Ractor.make_shareable(STATIC_TABLE)
    Ractor.make_shareable(STATIC_TABLE_SIZE)
  end
end

require_relative 'hpack/decoder'
require_relative 'hpack/dynamic_table'
require_relative 'hpack/encoder'
require_relative 'hpack/error'
require_relative 'hpack/field'
require_relative 'hpack/fields'
require_relative 'hpack/huffman'
require_relative 'hpack/integer'
require_relative 'hpack/option'
require_relative 'hpack/string'
