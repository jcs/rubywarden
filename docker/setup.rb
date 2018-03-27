#!/usr/bin/env ruby
#
# Copyright (c) 2017 Rodrigo Fernandes <rodrigo.fernandes@tecnico.ulisboa.pt>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

#
# Install bitwarden-ruby locally using docker and docker-compose
#

require 'getoptlong'
require 'securerandom'
require 'English'


def usage
  puts "usage: #{$0} [options]      "
  puts '  options:                  '
  puts '    --data-out, -o          '
  puts '    --domain, -d            '
  puts '    --email, -e             '
  puts '    --letsencrypt, -l       '
  puts '    --core-version, -c      '
  puts '    --web-version, -w       '
  puts '    --ruby-api-version, -r  '
end

def read_input(message, sensitive = false)
  print "#{message}: "
  system('stty -echo') if sensitive
  input = STDIN.gets.chomp
  system('stty echo')
  print "\n"
  input
end

def ask(message)
  print "#{message}? [Y/n] "
  !STDIN.gets.to_s.match(/(n|no)/i)
end

def continue_or_exit?(message = nil)
  unless ask(message || 'Continue')
    exit 1
  end
end

def exec(cmd)
  output = `#{cmd}`
  {
    :output   => output,
    :success? => $CHILD_STATUS.success?
  }
end

def fido(web_directory, url)
  puts 'Building FIDO U2F app id.'
  FileUtils.mkdir_p(web_directory)

  json = <<-END.gsub(/^\s+\|/, '')
    |{
    |  "trustedFacets": [
    |    {
    |      "version": {
    |        "major": 1,
    |        "minor": 0
    |      },
    |      "ids": [
    |        "#{url}",
    |        "ios:bundle-id:com.8bit.bitwarden",
    |        "android:apk-key-hash:dUGFzUzf3lmHSLBDBIv+WaFyZMI"
    |      ]
    |    }
    |  ]
    |}
  END

  File.open(File.expand_path(File.join(web_directory, 'app-id.json')), 'wb') do |file|
    file.puts(json)
  end
end

def app_settings(web_directory, domain, url)
  puts 'Building app settings.'
  FileUtils.mkdir_p(web_directory)

  json = <<-END.gsub(/^\s+\|/, '')
      |// Config Parameters
      |// Parameter:Url=#{url}
      |// Parameter:Domain=#{domain}
      |var bitwardenAppSettings = {
      |    apiUri: "#{url}/api",
      |    identityUri: "#{url}/identity",
      |    iconsUri: "#{url}/icons",
      |    stripeKey: null,
      |    braintreeKey: null,
      |    whitelistDomains: ["#{domain}"],
      |    selfHosted: true
      |};
  END

  File.open(File.expand_path(File.join(web_directory, 'settings.js')), 'wb') do |file|
    file.puts(json)
  end
end

def ssl_certificate(ssl_directory, domain)
  puts 'Generating self signed SSL certificate.'
  domain_dir = File.expand_path(File.join(ssl_directory, 'self', domain))
  FileUtils.mkdir_p(domain_dir)

  cmd = <<-EOS.gsub(/^[\s\t]*/, '').gsub(/[\s\t]*\n/, ' ').strip
    openssl req -x509 -newkey rsa:4096 -sha256 -nodes -days 365
    -keyout #{domain_dir}/private.key
    -out #{domain_dir}/certificate.crt
    -subj "/C=US/ST=New York/L=New York/O=8bit Solutions LLC/OU=bitwarden/CN={Domain}"
  EOS

  exec cmd
end

def dhparam(letsencrypt_dir)
  domain_dir = File.expand_path(File.join(letsencrypt_dir, 'live', domain))
  FileUtils.mkdir_p(domain_dir)

  exec "openssl dhparam -out #{domain_dir}/dhparam.pem 2048"
end

def docker_compose(docker_directory, http_port, https_port, core_version, web_version, ruby_api_version, nginx_proxy)
  puts 'Building docker-compose.yml.'
  FileUtils.mkdir_p(docker_directory)

  compose_path = File.expand_path(File.join(docker_directory, 'docker-compose.yml'))

  nginx_contents = <<-END.gsub(/^\s+\|/, '')
    |
    |  nginx:
    |    image: bitwarden/nginx:#{core_version}
    |    container_name: nginx
    |    restart: always
    |    ports:
    |      - '#{http_port}:80'
    |      - '#{https_port}:443'
    |    volumes:
    |      - ../nginx:/etc/bitwarden/nginx
    |      - ../letsencrypt:/etc/letsencrypt
    |      - ../ssl:/etc/ssl
  END
  nginx_contents = '' unless nginx_proxy

  contents = <<-END.gsub(/^\s+\|/, '')
    |# https://docs.docker.com/compose/compose-file/
    |# Parameter:HttpPort=#{http_port}
    |# Parameter:HttpsPort=#{https_port}
    |# Parameter:CoreVersion=#{core_version}
    |# Parameter:WebVersion=#{web_version}
    |# Parameter:RubyApiVersion=#{ruby_api_version}
    |version: '3'
    |services:
    |  web:
    |    image: bitwarden/web:#{web_version}
    |    container_name: web
    |    restart: always
    |    volumes:
    |      - ../web:/etc/bitwarden/web
    |  attachments:
    |    image: bitwarden/attachments:#{core_version}
    |    container_name: attachments
    |    restart: always
    |    volumes:
    |      - ../core/attachments:/etc/bitwarden/core/attachments
    |  api:
    |    image: rtfpessoa/bitwarden-ruby:#{ruby_api_version}
    |    container_name: api
    |    restart: always
    |    volumes:
    |      - ../db:#{ENV['DB_ROOT']}
    |    env_file:
    |      - global.env
    |      - ../env/global.override.env#{nginx_contents}
  END

  File.open(compose_path, 'wb') do |file|
    file.puts(contents)
  end
end

def env(docker_directory, env_directory, url, email, installation_id, installation_key, id_cert_password, duo_a_key, user_registration)
  puts 'Building docker environment files.'

  FileUtils.mkdir_p(docker_directory)
  docker_env_path = File.expand_path(File.join(docker_directory, 'global.env'))
  contents_docker = <<-END.gsub(/^\s+\|/, '')
    |ASPNETCORE_ENVIRONMENT=Production
    |globalSettings__selfHosted=true
    |globalSettings__baseServiceUri__vault=http://localhost
    |globalSettings__baseServiceUri__api=http://localhost/api
    |globalSettings__baseServiceUri__identity=http://localhost/identity
    |globalSettings__baseServiceUri__internalIdentity=http://identity
    |globalSettings__pushRelayBaseUri=https://push.bitwarden.com
    |globalSettings__installation__identityUri=https://identity.bitwarden.com
  END

  File.open(docker_env_path, 'wb') do |file|
    file.puts(contents_docker)
  end

  puts 'Building docker environment override files.'

  FileUtils.mkdir_p(env_directory)
  global_env_path = File.expand_path(File.join(env_directory, 'global.override.env'))
  contents_env    = <<-END.gsub(/^\s+\|/, '')
    |globalSettings__baseServiceUri__vault=#{url}
    |globalSettings__baseServiceUri__api=#{url}/api
    |globalSettings__baseServiceUri__identity=#{url}/identity
    |globalSettings__identityServer__certificatePassword=#{id_cert_password}
    |globalSettings__attachment__baseDirectory=/etc/bitwarden/core/attachments
    |globalSettings__attachment__baseUrl=#{url}/attachments
    |globalSettings__dataProtection__directory=/etc/bitwarden/core/aspnet-dataprotection
    |globalSettings__logDirectory=/etc/bitwarden/core/logs
    |globalSettings__licenseDirectory=/etc/bitwarden/core/licenses
    |globalSettings__duo__aKey=#{duo_a_key}
    |globalSettings__installation__id=#{installation_id}
    |globalSettings__installation__key=#{installation_key}
    |globalSettings__yubico__clientId=REPLACE
    |globalSettings__yubico__key=REPLACE
    |globalSettings__mail__replyToEmail=#{email}
    |globalSettings__mail__smtp__host=REPLACE
    |globalSettings__mail__smtp__username=REPLACE
    |globalSettings__mail__smtp__password=REPLACE
    |globalSettings__mail__smtp__ssl=true
    |globalSettings__mail__smtp__port=587
    |globalSettings__mail__smtp__useDefaultCredentials=false
    |globalSettings__disableUserRegistration=#{!user_registration}
  END

  File.open(global_env_path, 'wb') do |file|
    file.puts(contents_env)
  end
end

def nginx(nginx_directory, domain, url, ssl, trusted_ssl, self_signed, letsencrypt, diffie_hellman)
  puts 'Building nginx config.'
  FileUtils.mkdir_p(nginx_directory)

  ssl_path  =
    if letsencrypt
      "/etc/letsencrypt/live/#{domain}"
    elsif self_signed
      "/etc/ssl/self/#{domain}"
    else
      "/etc/ssl/#{domain}"
    end
  cert_file = letsencrypt ? 'fullchain.pem' : 'certificate.crt'
  key_file  = letsencrypt ? 'privkey.pem' : 'private.key'
  ca_file   = letsencrypt ? 'fullchain.pem' : 'ca.crt'

  diffie_hellman_contents = <<-END.gsub(/^\s+\|/, '')
    |
    |
    |  # Diffie-Hellman parameter for DHE ciphersuites, recommended 2048 bits
    |  ssl_dhparam #{ssl_path}/dhparam.pem;
    |
  END

  unless diffie_hellman
    diffie_hellman_contents = ''
  end

  trusted_contents = <<-END.gsub(/^\s+\|/, '')
    |
    |
    |  # OCSP Stapling ---
    |  # fetch OCSP records from URL in ssl_certificate and cache them
    |  ssl_stapling on;
    |  ssl_stapling_verify on;
    |
    |  ## verify chain of trust of OCSP response using Root CA and Intermediate certs
    |  ssl_trusted_certificate #{ssl_path}/#{ca_file};
    |
    |  resolver 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=300s;
    |
    |  # This will enforce HTTP browsing into HTTPS and avoid ssl stripping attack. 6 months age
    |  add_header Strict-Transport-Security max-age=15768000;
  END

  unless trusted_ssl
    trusted_contents = ''
  end

  ssl_contents = <<-END.gsub(/^\s+\|/, '')
    |
    |  return 301 #{url}$request_uri;
    |}
    |
    |server {
    |  listen 443 ssl http2;
    |  listen [::]:443 ssl http2;
    |  server_name #{domain};
    |
    |  ssl_certificate #{ssl_path}/#{cert_file};
    |  ssl_certificate_key #{ssl_path}/#{key_file};
    |
    |  ssl_session_timeout 30m;
    |  ssl_session_cache shared:SSL:20m;
    |  ssl_session_tickets off;#{diffie_hellman_contents}
    |  # SSL protocols TLS v1~TLSv1.2 are allowed. Disabed SSLv3
    |  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    |  # Disabled insecure ciphers suite. For example, MD5, DES, RC4, PSK
    |  ssl_ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4:@STRENGTH";
    |  # enables server-side protection from BEAST attacks
    |  ssl_prefer_server_ciphers on;#{trusted_contents}
    |
  END

  unless ssl
    ssl_contents = ''
  end

  nginx_file_path = File.expand_path(File.join(nginx_directory, 'default.conf'))
  contents        = <<-END.gsub(/^\s+\|/, '')
    |# Config Parameters
    |# Parameter:Ssl=#{ssl}
    |# Parameter:SelfSignedSsl=#{self_signed}
    |# Parameter:LetsEncrypt=#{letsencrypt}
    |# Parameter:Domain=#{domain}
    |# Parameter:Url=#{url}
    |# Parameter:DiffieHellman=#{diffie_hellman}
    |# Parameter:Trusted=#{trusted_ssl}
    |
    |server {
    |  listen 80 default_server;
    |  listen [::]:80 default_server;
    |  server_name #{domain};#{ssl_contents}
    |
    |  # X-Frame-Options is to prevent from click-jacking attack
    |  #add_header X-Frame-Options SAMEORIGIN;
    |
    |  # disable content-type sniffing on some browsers.
    |  add_header X-Content-Type-Options nosniff;
    |
    |  # This header enables the Cross-site scripting (XSS) filter
    |  add_header X-XSS-Protection "1; mode=block";
    |
    |  # This header controls what referrer information is shared
    |  add_header Referrer-Policy same-origin;
    |
    |  location / {
    |    proxy_pass http://web/;
    |  }
    |
    |  location = /app-id.json {
    |    proxy_pass http://web/app-id.json;
    |    proxy_hide_header Content-Type;
    |    add_header Content-Type $fido_content_type;
    |  }
    |
    |  location /attachments/ {
    |    proxy_pass http://attachments/;
    |  }
    |
    |  location /api/ { 
    |    proxy_pass http://api/api/; 
    |  }
    |
    |  location /identity/ {
    |    proxy_pass http://api/identity/;
    |  }
    |
    |  location /icons/ {
    |    proxy_pass http://api/icons/;
    |  }
    |}
  END

  File.open(nginx_file_path, 'wb') do |file|
    file.puts(contents)
  end
end


data_directory   = File.expand_path(File.join(Dir.pwd, 'bwdata'))
letsencrypt      = false
domain           = nil
core_version     = 'latest'
web_version      = 'latest'
ruby_api_version = 'dev'
email            = nil

begin
  GetoptLong.new(
    ['--data-out', '-o', GetoptLong::REQUIRED_ARGUMENT],
    ['--domain', '-d', GetoptLong::REQUIRED_ARGUMENT],
    ['--email', '-e', GetoptLong::REQUIRED_ARGUMENT],
    ['--letsencrypt', '-l', GetoptLong::OPTIONAL_ARGUMENT],
    ['--core-version', '-c', GetoptLong::REQUIRED_ARGUMENT],
    ['--web-version', '-w', GetoptLong::REQUIRED_ARGUMENT],
    ['--ruby-api-version', '-r', GetoptLong::REQUIRED_ARGUMENT]
  ).each do |opt, arg|
    case opt
      when '--data-out'
        data_directory = arg
      when '--domain'
        domain = arg
      when '--email'
        email = arg
      when '--letsencrypt'
        letsencrypt = arg.nil? || !arg.match(/(n|no|false)/i)
      when '--core-version'
        core_version = arg
      when '--web-version'
        web_version = arg
      when '--ruby-api-version'
        ruby_api_version = arg
      else
        puts 'No top-level command detected. Exiting...'
        exit(3)
    end
  end

rescue GetoptLong::InvalidOption
  usage
  exit (2)
end

puts 'Bitwarden setup...'

docker_directory      = File.expand_path(File.join(data_directory, 'docker'))
env_directory         = File.expand_path(File.join(data_directory, 'env'))
letsencrypt_directory = File.expand_path(File.join(data_directory, 'letsencrypt'))
nginx_directory       = File.expand_path(File.join(data_directory, 'nginx'))
ssl_directory         = File.expand_path(File.join(data_directory, 'ssl'))
web_directory         = File.expand_path(File.join(data_directory, 'web'))

installation_id = read_input('(!) Enter your installation id (get it at https://bitwarden.com/host)', true)

if installation_id.strip.empty?
  puts 'Unable to validate installation id.'
  exit(4)
end

installation_key = read_input('(!) Enter your installation key', true)

if installation_key.strip.empty?
  puts 'Unable to validate installation key.'
  exit(5)
end

# TODO: Validate installation Id and Key

nginx_proxy = ask('(!) Do you need nginx for SSL configuration')

ssl         = letsencrypt
self_signed = false

unless letsencrypt
  ssl = ask('(!) Do you have a SSL certificate to use')

  if ssl
    puts "Make sure 'certificate.crt' and 'private.key' are provided in the appropriate directory (see setup instructions)."
  end

end

identity_cert_password = SecureRandom.urlsafe_base64(32)

unless ssl
  ssl_certificate(ssl_directory, domain)
  ssl = self_signed = true
end

dhparam(letsencrypt_directory) if letsencrypt

default_ports = ask('(!) Do you want to use the default ports for HTTP (80) and HTTPS (443)')

http_port  = 80
https_port = 443

unless default_ports
  http_port  = read_input('(!) HTTP port')
  https_port = read_input('(!) HTTPS port') if ssl
end

domain = read_input('(!) Domain') if domain.nil?

if ssl
  url = "https://#{domain}"
  url = "#{url}:#{https_port}" unless https_port == 443
else
  url = "http://#{domain}"
  url = "#{url}:#{http_port}" unless http_port == 80
end

diffie_hellman =
  if ssl && !self_signed && !letsencrypt
    ask('(!) Use Diffie Hellman ephemeral parameters for SSL (requires dhparam.pem)')
  else
    letsencrypt
  end

trusted_ssl =
  if ssl && !self_signed && !letsencrypt
    ask('(!) Is this a trusted SSL certificate (requires ca.crt)')
  else
    letsencrypt
  end

nginx(nginx_directory, domain, url, ssl, trusted_ssl, self_signed, letsencrypt, diffie_hellman)

email = read_input('(!) Notifications email') if email.nil?

# TODO: Validate email

allow_user_registration = ask('(!) Allow user registration')
duo_a_key               = SecureRandom.urlsafe_base64(64)

env(docker_directory, env_directory, url, email, installation_id, installation_key, identity_cert_password, duo_a_key, allow_user_registration)

app_settings(web_directory, domain, url)

fido(web_directory, url)

docker_compose(docker_directory, http_port, https_port, core_version, web_version, ruby_api_version, nginx_proxy)

puts 'Bitwarden setup complete!'
