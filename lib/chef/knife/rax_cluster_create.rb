require 'chef/knife/rax_cluster_base'
require 'chef/knife/rackspace/rackspace_server_create'

class Chef
  class Knife
    class RaxClusterCreate < Knife
      attr_accessor :headers, :rax_endpoint 
      include Knife::RaxClusterBase
      banner "knife rax cluster create (cluster_name) [options]"
      deps do
        require 'fog'
        require 'readline'
        require 'chef/json_compat'
        require 'chef/knife/bootstrap'
        Chef::Knife::Bootstrap.load_deps
      end

      option :algorithm,
      :short => "-a Load_balacner_algorithm",
      :long => "--algorithm algorithm",
      :description => "Load balancer algorithm",
      :proc => Proc.new { |algorithm| Chef::Config[:knife][:algorithm] = algorithm }
      
	  option :blue_print,
	  :short => "-B Blue_print_file",
	  :long => "--map blue_print_file",
	  :description => "Path to blue Print json file",
	  :proc => Proc.new { |i| Chef::Config[:knife][:blue_print] = i.to_s }
      
      option :port,
      :short => "-lb_port port",
      :long => "--load-balancer-port port",
      :description => "Load balancer port",
      :proc => Proc.new { |port| Chef::Config[:knife][:port] = port}
      
      option :timeout,
      :short => "-t timeout",
      :long => "--load-balancer-timeout timeout",
      :description => "Load balancer timeout",
      :proc => Proc.new { |timeout| Chef::Config[:knife][:timeout] = timeout}
      
      option :generate_map_template,
      :short => "-G",
      :long => "--generate_map_template",
      :description => "Generate server map Template in current dir named map_template.json"
      
      option :session_persistence,
      :short => "-S on_or_off",
      :long => "--session-persistence session_persistence_on_or_off",
      :description => "Load balancer session persistence on or off",
      :proc => Proc.new { |session_persistence| Chef::Config[:knife][:session_persistence] = session_persistence}

      def generate_map_template
           file_name = "./map_template.json"
           template = %q(
           {
             "blue_print" : 
               {
                   "name_convention" : "web",
                   "run_list" : [
                     "recipe[apt]"
                   ],
                   "quantity" : 1,
                   "chef_env" : "dev",
                   "image_ref" : "a9753ff4-f46c-427d-9498-1358564f622f",
                   "flavor" : 2
                   }
             
     
           }
     )
     
           File.open(file_name, 'w') { |file| file.write(template)}
      end
      
      def deploy(blue_print)
        (File.exist?(blue_print)) ? map_contents = JSON.parse(File.read(blue_print)) : map_contents = JSON.parse(blue_print)
        sleep_interval = 1
        if map_contents.has_key?("blue_print")
          bp_values = map_contents['blue_print']
              bootstrap_nodes = []
              quantity = bp_values['quantity'].to_i
              quantity.times do |node_name|
                  node_name  = rand(900000000)
                  create_server = Chef::Knife::RaxClusterBuild.new
                  create_server.config[:identity_file] = config[:identity_file]
                  Chef::Config[:knife][:image] = bp_values['image_ref'] 
                  create_server.config[:chef_node_name] = bp_values['name_convention'] + node_name.to_s 
                  create_server.config[:environment] = bp_values['chef_env'] 
                  Chef::Config[:environment] = bp_values['chef_env']
                  create_server.config[:ssh_user] = config[:ssh_user]
                  create_server.config[:run_list] = bp_values['run_list']
                  Chef::Config[:knife][:flavor] = bp_values['flavor']
                  begin
                    bootstrap_nodes << Thread.new { Thread.current['server_return'] = create_server.run }
                  rescue
                    ui.msg "Bootstrapping failed"
                  end
                  
              end
              quantity.times do |times|
                if quantity > 20
                  sleep_interval = 3
                end
                begin
                  bootstrap_nodes[times].join
                  sleep(sleep_interval)
                rescue
                  print "Bootstrap failed"
                end
                
                
              end
        end
        
        
      end

      def run
        #Generate template config
		if config[:generate_map_template]
		  generate_map_template()
		  ui.msg "Map template saved as ./map_template.json"
		  exit()
		end
        
        
        if @name_args.empty? or @name_args.size > 1
		  ui.fatal "Please specify a single name for your cluster"
		  exit(1)
        end
        
        if config[:blue_print]
          deploy(config[:blue_print])
        end
        
      end
    
      
    end
  end
end
