set :puma_status, -> { "#{fetch(:deploy_to)} exec puma-status" }
set :puma_state,  -> { "#{fetch(:deploy_to)}/tmp/sockets/puma.state" }
set :puma_config, -> { " -c #{fetch(:deploy_to)}/shared/config/puma.rb -d" }
set :puma_sock,   -> { "#{fetch(:deploy_to)}/shared/tmp/sockets/puma.sock" }

set :puma_application_name, 'puma'
set :puma_service_name, -> { "#{fetch(:puma_application_name)}.service" }
set :puma_socket_name,  -> { "#{fetch(:puma_application_name)}.socket" }

set :puma_binary_id, 'pumactl'

set :sysctl_cmd,        'sudo systemctl'
set :systemd_unit_path, '/etc/systemd/system'
set :system_bundler, "#{ fetch(:deploy_to) } exec bundle"

set :puma_unit_user, 'puma'
set :puma_unit_type, 'exec'
set :puma_unit_delay, '5'
set :puma_unit_kill_mode, 'mixed'
set :puma_unit_restart_mode, 'on-failure'
set :puma_unit_wanted, 'multi-user.target'

namespace :puma do
  desc "Init systemd units"
  task :install do
      template_service = %{
[Unit]
Description=Puma HTTP Server
After=network.target
Requires=#{ fetch(:puma_socket_name) }

[Service]
  Type=#{ fetch(:puma_unit_type) }
  User=#{ fetch(:puma_unit_user) }
  WorkingDirectory=#{ fetch(:deploy_to) }
  ExecStart=#{fetch(:system_bundler)} exec #{fetch(:puma_binary_id)}  -c #{fetch(:puma_config)}
  ExecReload=/bin/pkill #{fetch(:puma_application_name)}
  ExecStop=/bin/pkill #{fetch(:puma_application_name)}
  Restart=#{ fetch(:puma_unit_restart_mode) }
  RestartSec=#{ fetch(:puma_unit_delay) }
  KillMode=#{ fetch(:puma_unit_kill_mode) }

  [Install]
  WantedBy=#{ fetch(:puma_unit_wanted) }
}

    template_socket = %{
[Unit]
Description=Puma HTTP Server Accept Sockets

[Socket]
ListenStream=#{ fetch(:puma_sock) }

NoDelay=false
ReusePort=false
Backlog=1024

[Install]
WantedBy=sockets.target
}
      service_path = fetch(:systemd_unit_path) + "/" + fetch(:puma_service_name)
      comment %{Creating service unit file}
      command %{ sudo touch #{service_path} }
      command %{ echo "#{ template_service }" | sudo tee -a #{ service_path } }

      socket_path = fetch(:systemd_unit_path) + "/" + fetch(:puma_socket_name)
      comment %{Creating socket unit file}
      command %{ sudo touch #{socket_path} }
      command %{ echo "#{ template_socket }" | sudo tee -a #{ socket_path } }

      comment %{Reloading systemctl daemon}
      command %{ #{ fetch(:sysctl_cmd) } daemon-reload }

      comment %{Enabling services }
      command %{ #{ fetch(:sysctl_cmd) } enable #{ socket_path } }
      command %{ #{ fetch(:sysctl_cmd) } enable #{ service_path } }
  end

  desc "Remove units"
  task :uninstall do
      command %{ #{ fetch(:sysctl_cmd) } disable #{fetch(:puma_service_name)} }
      command %{ sudo rm #{File.join(fetch(:systemd_unit_path), fetch(:puma_service_name))}  }

      command %{ #{ fetch(:sysctl_cmd) } disable #{fetch(:puma_socket_name)} }
      command %{ sudo rm #{File.join(fetch(:systemd_unit_path), fetch(:puma_socket_name))}  }

      comment %{Reloading systemctl daemon}
      command %{ #{ fetch(:sysctl_cmd) } daemon-reload }
  end

  desc "Check puma state"
  task :state => :remote_environment do 
      command %{cd #{fetch(:current_path)} && #{fetch(:puma_status)} #{fetch(:puma_state)} }
  end

  desc "Check puma.service status"
  task :status => :remote_environment do
      command %{ #{ fetch(:sysctl_cmd) } status #{fetch(:puma_socket_name)} #{fetch(:puma_service_name)} }
  end

  desc "Start puma.service and puma.socket"
  task :start => :remote_environment do
      command %{ #{ fetch(:sysctl_cmd) } start #{fetch(:puma_socket_name)} #{fetch(:puma_service_name)} }
  end

  desc "Stop puma.service and puma.socket"
  task :stop => :remote_environment do
      command %{ #{ fetch(:sysctl_cmd) } stop #{fetch(:puma_socket_name)} #{fetch(:puma_service_name)} }
  end

  desc "Restart puma.service "
  task :restart => :remote_environment do
      command %{ #{ fetch(:sysctl_cmd) } restart #{fetch(:puma_service_name)} }
  end

  desc "Restart puma.service and puma.socket"
  task :hard_restart => :remote_environment do  
      command %{ #{ fetch(:sysctl_cmd) } restart #{fetch(:puma_socket_name)} #{fetch(:puma_service_name)} }
  end

end
