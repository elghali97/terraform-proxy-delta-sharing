#! /bin/bash
sudo apt-get -y update
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
sudo apt-get -y install nginx

sudo mkdir -p /usr/local/nginx/logs

cat > nginxconfig.conf << EOF
worker_processes 1;
pid /run/nginx.pid;

# Single process: 
# handle up to (worker_connections/2) users to account for incoming/outgoing connections
events {
  worker_connections 1024;
}

http {

  # Simple defaults for downloading files
	default_type application/octet-stream;

  # Logging: by default, off
	access_log /usr/local/nginx/logs/access.log;
	error_log  /usr/local/nginx/logs/error.log;

  # Optimize sending static files and saving a copy
  # https://thoughts.t37.net/nginx-optimization-understanding-sendfile-tcp-nodelay-and-tcp-nopush-c55cdd276765
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;

  # Increase the default hashtables size for server name and lookup
  # https://gist.github.com/muhammadghazali/6c2b8c80d5528e3118613746e0041263
	types_hash_max_size 2048;
	server_names_hash_bucket_size 64;

  ## Timeout optimization from https://www.digitalocean.com/community/tutorials/how-to-optimize-nginx-configuration
  client_body_timeout 12;
  client_header_timeout 12;
  keepalive_timeout 15;
  send_timeout 10;

  # Simple webserver on port 80
  server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    # return 301 https://\$host:8443\$request_uri;
  #}

  #server {
    #listen 8443;
    #server_name ${NGINX_SERVER_NAME};

    ## Forces a client (browser) to remember to go to this site via https
    ## but it can be difficult to back out of, so should set a small max-age to test it out.
    ## https://www.nginx.com/blog/http-strict-transport-security-hsts-and-nginx/
    # add_header Strict-Transport-Security "max-age=31536000"

    # SSL settings
    #ssl on;

    # From https://cipherli.st/
    #ssl_protocols TLSv1.2;# Requires nginx >= 1.13.0 else use TLSv1.2
    #ssl_prefer_server_ciphers on; 
    #ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    #ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
    #ssl_session_timeout  10m;
    #ssl_session_cache shared:SSL:10m;
    #ssl_session_tickets off; # Requires nginx >= 1.5.9
    #ssl_stapling on; # Requires nginx >= 1.3.7
    #ssl_stapling_verify on; # Requires nginx => 1.3.7

    # This is disabled for now, but should be turned on when a real certificate is used
    # add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none; 

    location / {
      # Proxy S3 location
      proxy_pass https://${NGINX_S3_BUCKET}.s3.amazonaws.com;

      # Usually a good practice to pass the real IP to the origin server
      proxy_set_header  X-Real-IP \$remote_addr;
      proxy_set_header  X-Forwarded-For \$proxy_add_x_forwarded_for;
      add_header        X-Cache-Status \$upstream_cache_status;

      # Hide these unused aws headers
      proxy_hide_header x-amz-id-2;
      proxy_hide_header x-amz-request-id;
      proxy_hide_header x-amz-bucket-region;
      proxy_hide_header Set-Cookie;
    }
  }
}
EOF

sudo cp nginxconfig.conf nginxconfig.conf.bak
sudo mv nginxconfig.conf /etc/nginx/nginx.conf
sudo systemctl enable nginx
sudo systemctl stop nginx
sudo systemctl start nginx