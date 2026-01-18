require_relative 'spec_helper'

RSpec.describe HTTPResponse do
  it 'should validate' do
    expect { HTTPResponse.new(600, {}, nil).validate }.to raise_error Error::InvalidHTTPResponseError
    expect { HTTPResponse.new(200, { "\x00key" => 'value' }, nil).validate }.to raise_error Error::InvalidHTTPResponseError
    expect { HTTPResponse.new(200, { 'key:' => 'value' }, nil).validate }.to raise_error Error::InvalidHTTPResponseError
    expect { HTTPResponse.new(200, { 'key' =>  "one\ntwo" }, nil).validate }.to raise_error Error::InvalidHTTPResponseError
    expect { HTTPResponse.new(200, { 'key' =>  ' value' }, nil).validate }.to raise_error Error::InvalidHTTPResponseError
    expect { HTTPResponse.new(200, { 'key' =>  "value\t" }, nil).validate }.to raise_error Error::InvalidHTTPResponseError
  end
end
