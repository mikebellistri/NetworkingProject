How to Run Our Code:

Our code is run using the config file: project.config This file has 6 parameters and are as follows

	Maximum Packet Size
	Path to nodes-to-addresses file
	Path to weights file
	Update Interval
	Path to Routing Table Dump Foler 
	Dump Interval

The config file is used as a command line argument. Our code is called using the ruby call: ruby Node.rb project.config

When running our code make sure the keys.txt file is completely empty every time you run it

Our code can also be run using the shell script file: test.sh

Once the message "YOU CAN NOW EXECUTE COMMANDS" appears you can enter commands into each terminal

The weights file must be structured: source,dest,weight ex. 10.0.0.20,10.0.0.21,4 The nodes-to-adresses should be structed: hostname address (where the whitespace is a tab) ex. n1 10.0.0.20

User can run three commands: SENDMSG, TRACEROUTE, PING in form

SENDMSG [DEST] [MSG]

PING [DST] [NUMPING] [DELAY]

TRACEROUTE [DST]


What Our Code Does:

Our code creates 3 threads: a recieving thread, a routing thread, and a dumping thread

The recieving thread accepts packets passed over the network. Depending on the type of packet recieved this thread will decide what action to take.

The routing thread checks for a topology change. If it notices a change it will change it's own topology and send out the change over the network. It will check for changes based on the update interval defined in the project.config file.

The dump thread gets the routing table stored in the node and outputs the routing table into a text file stored at the path specified in the config file. It is dumped every dump interval also specified in the config file.

The routing and dump threads sleep to allow our script to be run on every node before it begins sending packets. The routing thread also sleeps before getting the routing table from dijkstra to allow time to recieve all packets from the topology change.

The sending thread waits for input from the user. Once the user has input a message a circuit packet is sent out to establish the circuit. Once a circuit has been established the message is sent out based on its length. If it is longer then the max packet size then the message is fragmented and send out.

A node will know if it has recieved a fragment message based on the FRAGMENT control message. It will wait unti it recieves a FRAGMENT_END packet before outputting the result.

A node uses the topo_hash from Part 1 to building the circuit table

Ping sends NUMPING packets to packet to DST with DELAY seconds and wait for an acknowledgement and displays the RTT

Traceroute sends packets to DST and intermediate nodes send a acknowledgement back for output.

We used onion routing as our security extension. When a message is about to be sent a circuit is created to the destination. As the circuit is created packets are sent back to the source so the source knows the full path. The source has to know the full path in order to encrypt the message.

We are protecting against active listening(man in the middle) and packet sniffing types of attacks. With onion routing a listener could know the keys of the each node in the system but without knowing the path they couldn't decrypt it because the packet is layered with encryption. The encryption on the packet is peeled away in a very specific order and without knowing the order you can't decrypt it.

The message is then put into a packet and the entire packet is encrypted using Caesar Cipher and the key for the last node in the chain. Once this is done the cipher is put into a wrapper class consisting of a cipher and a node field. Each wrapper is then encrypted using the next node in the chain and put within another wrapper class. This makes the onion and once it has been created it is sent out.

Once a node recieves data it determines if it is a wrapper or a packet. If it is a wrapper it will decrypt the wrapper's cipher using its own key. The resulting data structure is then sent to the next node along the chain. 
