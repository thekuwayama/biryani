require_relative '../spec_helper'

RSpec.describe HTTP::Response do
  it 'should validate' do
    expect { HTTP::Response.new(600, {}, nil).validate }.to raise_error HTTP::Error::InvalidHTTPResponseError
    expect { HTTP::Response.new(200, { "\x00key" => 'value' }, nil).validate }.to raise_error HTTP::Error::InvalidHTTPResponseError
    expect { HTTP::Response.new(200, { 'key:' => 'value' }, nil).validate }.to raise_error HTTP::Error::InvalidHTTPResponseError
    expect { HTTP::Response.new(200, { 'key' =>  "one\ntwo" }, nil).validate }.to raise_error HTTP::Error::InvalidHTTPResponseError
    expect { HTTP::Response.new(200, { 'key' =>  ' value' }, nil).validate }.to raise_error HTTP::Error::InvalidHTTPResponseError
    expect { HTTP::Response.new(200, { 'key' =>  "value\t" }, nil).validate }.to raise_error HTTP::Error::InvalidHTTPResponseError
  end
end
