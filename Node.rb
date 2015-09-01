require 'socket'
require 'thread'
require 'yaml'
require 'monitor'

# Authors: Zack Knopp, Kevin Gutierrez, Mike Bellistri

class Wrapper
	attr_accessor:cipher,:node
	def initialize()
		
	end

	def to_s
		puts "WRAPPER #{node}"
	end
end

class Packet

	attr_accessor:msg_type,:seq_num,:source,:dest,:topo_hash,:data

	def initialize(type, source, dest, topo_hash, data)
		@msg_type = type
		@seq_num = 0
		@source = source
		@dest = dest
		@topo_hash = topo_hash
		@data = data
	end

	def to_s
		puts "#{msg_type} #{source} #{dest} #{data}"
	end
end

class Node

	attr_accessor:name,:ip_addrs,:adj_hash,:seq_hash,:topo_hash,:lock,:routing_table,:circuit_table,:frag_str, :time, :count, :key_hash, :key

	def initialize(name)
		@name = name
		@key_hash = Hash.new
		@ip_addrs = Array.new
		@adj_hash = Hash.new
		@circuit_table = Hash.new
		@seq_hash = {name => 0}
		@routing_table = Hash.new
		@topo_hash = Hash.new
		@lock = Monitor.new
		@frag_str = ""
		@time = Time.now
		@count = 0
	end

	def add_topo(source, dest_node, cost)
		if(@topo_hash[source] == nil)
			tmp = Hash.new
			tmp[dest_node] = cost
			@topo_hash[source] = tmp
		else
			@topo_hash[source][dest_node] = cost
		end
	end

	def file_has_changed(file)
		has_changed = false
		f = open(file)
		while line = f.gets
			s, d, c = line.split(",")
			c = c.to_i
			#puts "#{s} #{d} #{c}"
			if(ip_addrs.include?(s) == true)
				if(adj_hash[d] != c)
					has_changed = true
				end
			end
		end
		f.close
		return has_changed
	end

	def add_route(route_name, ip_addr)
		@circuit_table[route_name] = ip_addr
	end

	def add_key(source_node, key)
		@key_hash[source_node] = key
	end
end

# Gets the name of the node given an IP address
def get_name(ip_addr, file)
	nodes_to_addr_file = open(file)
	while nodes_to_addr_line = nodes_to_addr_file.gets
		name_of_node, ip_addr_file = nodes_to_addr_line.split(" ")
		ip_addr_file.chomp!
		if(ip_addr == ip_addr_file)
			return name_of_node
		end
	end
end

# Gets the ip address of the node given a node name
def get_ip(name, file)
	f = open(file)
	while line = f.gets
		name_of_node, ip_addr = line.split(" ")
		ip_addr.chomp!
		if(name == name_of_node)
			return ip_addr
		end
	end
end

def get_link(name, node, file)
	f = open(file)
	test = ""
	while line = f.gets
		name_of_node, ip_addr = line.split(" ")
		ip_addr.chomp!
		if(name == name_of_node)
			node.adj_hash.each_key{|k|
				if k == ip_addr
					test = ip_addr
				end
			}
		end
	end
	f.close
	return test
end

def gen_key()
	key = 0
	while(key == 0)
		key = rand(127)
	end
	return key
end

#Shortest path algorithm
def dijkstra (graph, src)
	dist = {}
	prev = {}
	visit = []
	route = {}

	graph.each_key{ |k| 
		dist[k] =  10000
		prev[k] = nil
		visit.push(k)
	}

	dist[src] = 0

	while !visit.empty? 
		u = minDist(visit,dist)
		visit.delete(u)
		graph[u].each { |k,v|
	
			alt = dist[u] + v
			if alt < dist[k] then
				dist[k] = alt
				prev[k] = u
	 		end
	 	}
	end

	
	graph.each_key{|k|
		check = k
		neighbor = false
		if k == src then
			route[k] = { k => dist[k]}
		else
			while neighbor == false do
				if prev[check] == src then
					neighbor = true
					next_h = check
				end
				check = prev[check]
			end
			route[k]= {next_h => dist[k]}
		end
	}

	return route
end

def minDist (x,dist)

	max_dist = 10000
	node = nil
	x.each { |k|
		if dist[k] < max_dist then
			max_dist = dist[k]
			node = k
		end
	}

	return node
end

def calc_next_hop(node, dest_node, node_line)
	tmp = ""
	route = node.routing_table
	route.each_key{ |dest|
	if(dest_node == dest)
		next_hop = route[dest].keys.to_s
		tmp = next_hop
	end
	}
	next_hop = get_link(tmp,node,node_line)
	return next_hop
end

def encrypt(key, message)
	encrypt = ""
	message.each_byte{ |c|
		a = c - key
		if a < 0
			a = a + 128
		end
		encrypt = encrypt + a.chr
	}
	return encrypt
end

def decrypt(key, message)
	decrypt = ""
	message.each_byte{ |c|
		b = c + key
		if b >= 128
			b = b - 128
		end
		decrypt = decrypt + b.chr
	}
	return decrypt
end

def get_key(node)
	key_file = open("keys.txt")
	while line = key_file.gets
		test_node, key = line.split(" ")
		if(node == test_node)
			key.chomp!
			return key.to_i
		end
	end
end

def wrap(path_to_take, send_packet)

	wrapper = Wrapper.new
	send_obj = YAML::dump(send_packet)

	key = get_key(path_to_take[0])
	wrapper.cipher = encrypt(key, send_obj)
	wrapper.node = path_to_take[0]

	path_to_take.shift

	path_to_take.each{ |n|
		tmp = wrapper
		wrapper = Wrapper.new
		key = get_key(n)
		tmp = YAML::dump(tmp)
		wrapper.cipher = encrypt(key, tmp)
		wrapper.node = n
	}
	return wrapper
end

def copy(old_arr)
	new_arr = Array.new
	old_arr.each{ |e|
		new_arr.push(e)
	}
	return new_arr
end

# Variables
threads = Array.new

# Execute hostname to get name of the node
name_of_node = `hostname`
name_of_node.chomp!
node = Node.new(name_of_node)

# Process config file

config_file = open(ARGV[0])

max_size = config_file.gets
max_size.chomp!
max_size = max_size.to_i

node_line = config_file.gets
node_line.chomp!
nodes_to_addr_file = open(node_line)

link_line = config_file.gets
link_line.chomp!
link_file = open(link_line)

update_interval = config_file.gets
update_interval.chomp!
update_interval = update_interval.to_i

routing_path_line = config_file.gets
routing_path_line.chomp!

dump_interval = config_file.gets
dump_interval.chomp!
dump_interval = dump_interval.to_i

config_file.close

# Get ip addresses assoc with the node
while (nodes_to_addr_line = nodes_to_addr_file.gets)
	name_of_node, ip_addr = nodes_to_addr_line.split(" ")
	if(name_of_node == node.name)
		node.ip_addrs.push(ip_addr)
	end
end

# Get links between nodes and the cost
while (line = link_file.gets)
	source_node, dest_node, cost = line.split(",")
	if(node.ip_addrs.include?(source_node))
		cost = cost.to_i
		node.adj_hash[dest_node] = cost
		n = get_name(dest_node, node_line)
		node.add_topo(node.name,n,cost)
	end
end

nodes_to_addr_file.close
link_file.close

# Recieving Thread
threads << Thread.new do
	srv_sock = TCPServer.open(9999)
	recv_length = 255
	while(1)
		data = ""
		client = srv_sock.accept
		while(tmp = client.recv(recv_length))
			data += tmp
			break if tmp.length < recv_length
		end

		packet = YAML::load(data)
		if(packet.class == Packet)
			if(packet.msg_type == "LINK_PACKET")
				if(node.seq_hash[packet.source] == nil || node.seq_hash[packet.source] < packet.seq_num)

					# Updates the seq num for the source
					node.seq_hash[packet.source] = packet.seq_num

					# Updates nodes topo table with packets
					node.topo_hash[packet.source] = packet.topo_hash

					# Send recieved packet out to neighbors
					recv_serialized_obj = YAML::dump(packet)
					node.adj_hash.each_key{ |neighbor|
						name_of_neighbor = get_name(neighbor, node_line)
						if(packet.source != name_of_neighbor)
							recv_sockfd = TCPSocket.open(neighbor, 9999)
							recv_sockfd.send(recv_serialized_obj, 0)
							recv_sockfd.close
						end
					}
				end
			elsif(packet.msg_type == "CIRCUIT")
				if(node.ip_addrs.include?(packet.dest) == false)
					next_hop = calc_next_hop(node, packet.source, node_line)
					out_packet = Packet.new("KEY", node.name, packet.source, nil, node.key)
					serialized_obj = YAML::dump(out_packet)
					send_sockfd = TCPSocket.open(next_hop, 9999)
					send_sockfd.send(serialized_obj, 0)
					send_sockfd.close


					dest_name = get_name(packet.dest, node_line)
					next_hop = calc_next_hop(node, dest_name, node_line)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(next_hop, 9999)
					node.add_route(packet.dest, next_hop)
					sock.send(obj, 0)
					sock.close
				end
			elsif(packet.msg_type == "KEY")
				if(node.ip_addrs.include?(get_ip(packet.dest, node_line)) == false)
					next_hop = calc_next_hop(node, packet.dest, node_line)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(next_hop, 9999)
					sock.send(obj, 0)
					sock.close
				else
					node.add_key(packet.source, packet.data)
				end
			elsif(packet.msg_type == "SENDMSG")
				if(node.ip_addrs.include?(packet.dest) == false)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(node.circuit_table[packet.dest], 9999)
					sock.send(obj, 0)
					sock.close
				else
					source_ip = get_ip(packet.source, node_line)
					$stderr.puts "RECIEVED MSG #{source_ip} #{packet.data}"
				end
			elsif(packet.msg_type == "FRAGMENT_START")
				if(node.ip_addrs.include?(packet.dest) == false)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(node.circuit_table[packet.dest], 9999)
					sock.send(obj, 0)
					sock.close
				else
					node.frag_str = ""
				end
			elsif(packet.msg_type == "FRAGMENT")
				if(node.ip_addrs.include?(packet.dest) == false)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(node.circuit_table[packet.dest], 9999)
					sock.send(obj, 0)
					sock.close
				else
					node.frag_str = node.frag_str + packet.data
				end
			elsif(packet.msg_type == "FRAGMENT_END")
				if(node.ip_addrs.include?(packet.dest) == false)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(node.circuit_table[packet.dest], 9999)
					sock.send(obj, 0)
					sock.close
				else
					node.frag_str = node.frag_str + packet.data
					tmp = node.frag_str
					source_ip = get_ip(packet.source, node_line)
					puts "RECIEVED MSG #{source_ip} #{tmp}"
				end
			elsif (packet.msg_type == "PING")
				if (node.ip_addrs.include?(packet.dest) == false)
					dest_node = get_name(packet.dest, node_line)
					next_hop = calc_next_hop(node, dest_node, node_line)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(next_hop, 9999)
					sock.send(obj, 0)
					sock.close
				else
					next_hop = calc_next_hop(node, packet.source, node_line)
					out_packet = Packet.new("PING_ACK", packet.dest, packet.source, nil, "")
					serialized_obj = YAML::dump(out_packet)
					send_sockfd = TCPSocket.open(next_hop, 9999)
					send_sockfd.send(serialized_obj, 0)
					send_sockfd.close
				end
			elsif (packet.msg_type == "PING_ACK")
				if (node.ip_addrs.include?( get_ip(packet.dest, node_line) ) == false)
					next_hop = calc_next_hop(node, packet.dest, node_line)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(next_hop, 9999)
					sock.send(obj, 0)
					sock.close
				else
					time = Time.now - node.time
					puts "PING recieved from #{packet.source} in #{time} seconds"

				end
			elsif (packet.msg_type == "TRACEROUTE")
				if (node.ip_addrs.include?(packet.dest) == false)
					dest_node = get_name(packet.dest, node_line)
					next_hop = calc_next_hop(node, dest_node, node_line)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(next_hop, 9999)
					sock.send(obj, 0)
					sock.close
					next_hop = calc_next_hop(node, packet.source, node_line)
					out_packet = Packet.new("TRACEROUTE_ACK", node.name, packet.source, nil, "")
					serialized_obj = YAML::dump(out_packet)
					send_sockfd = TCPSocket.open(next_hop, 9999)
					send_sockfd.send(serialized_obj, 0)
					send_sockfd.close
				end
			elsif (packet.msg_type == "TRACEROUTE_ACK")
				if (node.ip_addrs.include?( get_ip(packet.dest, node_line) ) == false)
					next_hop = calc_next_hop(node, packet.dest, node_line)
					obj = YAML::dump(packet)
					sock = TCPSocket.open(next_hop, 9999)
					sock.send(obj, 0)
					sock.close
				else
					node.count += 1
					ip_a = get_ip(packet.source,node_line) 
					puts " #{node.count}   #{packet.source}(#{ip_a})"

				end
			else
				puts "RECIEVED A PACKET"
			end
		else
			key = get_key(packet.node)
			tmp = decrypt(key, packet.cipher)
			tmp = YAML::load(tmp)
			if(tmp.class == Wrapper)
				next_hop = calc_next_hop(node, tmp.node, node_line)
				sock = TCPSocket.open(next_hop, 9999)
				obj = YAML::dump(tmp)
				sock.send(obj, 0)
				sock.close
			else
				obj = YAML::dump(tmp)
				sock = TCPSocket.open(node.circuit_table[tmp.dest], 9999)
				sock.send(obj, 0)
				sock.close
			end
		end	
	end
end

stop_writing = false
init = true

$file_lock = Monitor.new

$file_lock.synchronize{
	node.key = gen_key
	key_file = File.open("keys.txt",'a')
	str = node.name + "\t" + node.key.to_s + "\n"
	key_file.write(str)
	key_file.close
}

# Routing Thread
threads << Thread.new do
	sleep(20)
	while(1)
		flag = false
		sleep(update_interval)

		#Checks for topology change
		if(node.file_has_changed(link_line))
			flag = true
		end
	
		if(init == true || flag == true)
			init = false

			#If topology changed found update topology hash
			if(flag == true && init == false)
				link_file = File.open(link_line)
				while (line = link_file.gets)
					source_node, dest_node, cost = line.split(",")
					if(node.ip_addrs.include?(source_node))
						cost = cost.to_i
						node.adj_hash[dest_node] = cost
						n = get_name(dest_node, node_line)
						node.add_topo(node.name,n,cost)
					end
				end
				link_file.close
			end

			#Sends Link State Packet to neighbors
			node.adj_hash.each_key{ |neighbor|
				out_packet = Packet.new("LINK_PACKET", node.name, neighbor, node.topo_hash[node.name],"")
				out_packet.seq_num = node.seq_hash[node.name] + 1
				serialized_obj = YAML::dump(out_packet)
				sockfd = TCPSocket.open(neighbor, 9999)
				sockfd.send(serialized_obj, 0)
				sockfd.close
			}

			node.seq_hash[node.name] += 1

			#Update routing table
			sleep(20)
			puts "YOU CAN NOW EXECUTE COMMANDS"
			route = dijkstra(node.topo_hash, node.name)
			node.routing_table = route
		end
		
	end
end

# Dump Thread
threads << Thread.new do
	sleep (update_interval+30)
	while(1)
		sleep(dump_interval)
		route = node.routing_table
		path = routing_path_line + "/routing_table_#{node.name}.txt"
		str = ""
		route.each_key{ |dest|
			str = str + "#{node.name},#{dest},"
			route[dest].each{ |nextHop,cost|
				str = str + "#{cost},#{nextHop}\n"
			}
		}
		f = File.open(path, 'w')
		f.write(str)
		f.close()
	end
end

# Sending Thread
threads << Thread.new do
	while(1)

		send_line = $stdin.gets.chomp

		if (send_line =~ /(PING) ([0-9]+.[0-9]+.[0-9]+.[0-9]+) ([0-9]+) ([0-9]+)/) then
			msg_type = $1
			destination = $2
			numpings = $3.to_i
			delay = $4.to_i
			
			count = 0

			while (count < numpings)
				dest_node = get_name(destination, node_line)
				next_hop = calc_next_hop(node, dest_node, node_line)
				out_packet = Packet.new("PING", node.name, destination, nil, "")
				serialized_obj = YAML::dump(out_packet)
				send_sockfd = TCPSocket.open(next_hop, 9999)
				send_sockfd.send(serialized_obj, 0)
				send_sockfd.close
				node.time = Time.now
				sleep(delay)
				count += 1
			end

		elsif (send_line =~ /(TRACEROUTE) ([0-9]+.[0-9]+.[0-9]+.[0-9]+)/)
			msg_type = $1
			destination = $2
			dest_node = get_name(destination, node_line)
			next_hop = calc_next_hop(node, dest_node, node_line)
			node.count = 0
			puts "traceroute to #{destination}"
			out_packet = Packet.new("TRACEROUTE", node.name, destination, nil, "")
			serialized_obj = YAML::dump(out_packet)
			send_sockfd = TCPSocket.open(next_hop, 9999)
			send_sockfd.send(serialized_obj, 0)
			send_sockfd.close

		elsif send_line =~ /(SENDMSG) ([0-9]+.[0-9]+.[0-9]+.[0-9]+) (.+)/
			msg_type = $1
			destination = $2
			message = $3
			message.chomp!
			dest_node = get_name(destination, node_line)
			next_hop = calc_next_hop(node, dest_node, node_line)
			
			# Set up circuit packet
			out_packet = Packet.new("CIRCUIT", node.name, destination, nil, "")
			serialized_obj = YAML::dump(out_packet)
			send_sockfd = TCPSocket.open(next_hop, 9999)

			# Opens first circuit path
			node.add_route(destination, next_hop)
			send_sockfd.send(serialized_obj, 0)
			send_sockfd.close
			
			sleep(5)

			# Create wrapper
			
			path = Array.new

			# Add path to wrapper
			node.key_hash.each_key{ |key|
				path.push(key)
			} 			

			if(message.length <= max_size)
				send_packet = Packet.new(msg_type, node.name, destination, nil, message)
				send_sockfd = TCPSocket.open(next_hop, 9999)
				tmp = copy(path)
				wrapper = wrap(tmp, send_packet)
				serialized_wrapper = YAML::dump(wrapper)
				send_sockfd.send(serialized_wrapper, 0)
				send_sockfd.close
			else
				str = ""
				send_sockfd = TCPSocket.open(next_hop, 9999)
				send_packet = Packet.new("FRAGMENT_START", node.name, destination, nil, nil)
				tmp = copy(path)
				wrapper = wrap(tmp, send_packet)
				send_obj = YAML::dump(wrapper)
				send_sockfd.send(send_obj, 0)
				send_sockfd.close
				send_sockfd = TCPSocket.open(next_hop, 9999)
				message.each_char{ |c|
					if(str.length < max_size)
						str = str + c
					end
					if(str.length == max_size)
						send_packet = Packet.new("FRAGMENT", node.name, destination, nil, str)
						tmp = copy(path)
						wrapper = wrap(tmp, send_packet)
						send_obj = YAML::dump(wrapper)
						send_sockfd.send(send_obj, 0)
						send_sockfd.close
						send_sockfd = TCPSocket.open(next_hop, 9999)
						str = ""
					end
				}
				send_packet = Packet.new("FRAGMENT_END", node.name, destination, nil, str)
				tmp = copy(path)
				wrapper = wrap(tmp, send_packet)
				send_obj = YAML::dump(wrapper)
				send_sockfd.send(send_obj, 0)
				send_sockfd.close
			end
		end
	end
end

threads.each{ |t|
	t.join
}
