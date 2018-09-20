## Installation on Debian 9

Update your environnement

	apt-get update && apt-get dist-upgrade -y

Install system dependance

	apt -y install git ruby-full build-essential libsqlite3-dev

Create user to run rubywarden service

	adduser --disabled-password --disabled-login rubywarden
	
Deployement 

	su - rubywarden
	git clone https://github.com/jcs/rubywarden.git
	gem install bundler --user-install
	cd rubywarden
	bundle install --deployment 
	PATH=/home/rubywarden/.gem/ruby/2.3.0/bin:$PATH
	env RACK_ENV=production bundle exec rake db:migrate
	
Test

	env RACK_ENV=production bundle exec rackup -p 4567 config.ru

Go back to root user to install the service
	exit 

	cat << eof > /etc/systemd/system/rubywarden.service
	[Unit]
	Description=rubywarden service

	[Service]
	Type=simple
	User=rubywarden
	WorkingDirectory=/home/rubywarden/rubywarden
	Environment="RACK_ENV=production"
	#Environment="ALLOW_SIGNUPS=1"
	ExecStart=/home/rubywarden/.gem/ruby/2.3.0/bin/bundle exec rackup -p 4567 config.ru
	Restart=always

	[Install]
	WantedBy=multi-user.target
	eof

	systemctl enable rubywarden.service
	systemctl start rubywarden.service

To allow signup edit /etc/systemd/system/rubywarden.service and uncomment ALLOW_SIGNUPS=1

	systemctl daemon-reload
	systemctl restart rubywarden.service
	
