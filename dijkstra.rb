
def dijkstra (graph, src)
	dist = {}
	prev = {}
	visit = []
	route = {}

	graph.each_key{ |k| 
		dist[k] =  Float::INFINITY
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
			route[k] = nil
		elsif prev[k] == src then
			route[k] = k
		else
			while neighbor == false do
				graph[src].each_key{ |neigh|
					if prev[check] == neigh then
						neighbor = true
					end
				}
				check = prev[check]
			end
			route[k]=check
		end
	}

	return route
end

def minDist (x,dist)

	max_dist = Float::INFINITY
	node = nil
	x.each { |k|
		if dist[k] < max_dist then
			max_dist = dist[k]
			node = k
		end
	}

	return node
end
