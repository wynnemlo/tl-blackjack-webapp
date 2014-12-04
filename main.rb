require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'pizzasauce' 

get '/' do
  "Hi there, this is my first try at rendering text."
end

get '/bet' do
end

get '/game' do
end