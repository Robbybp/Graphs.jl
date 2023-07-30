const UNMATCHED = nothing

"""
    AbstractMaximumMatchingAlgorithm

Abstract type for maximum cardinality matching algorithms
"""
abstract type AbstractMaximumMatchingAlgorithm end

"""
    HopcroftKarpAlgorithm

The [Hopcroft-Karp algorithm](https://en.wikipedia.org/wiki/Hopcroft-Karp_algorithm)
for computing a maximum cardinality matching of a bipartite graph.
"""
struct HopcroftKarpAlgorithm <: AbstractMaximumMatchingAlgorithm end

"""
Determine whether an augmenting path exists and mark distances
so we can compute shortest-length augmenting paths in the DFS.
"""
function _hk_augmenting_bfs!(
    graph::Graph{T},
    set1::Vector{T},
    matching::Dict{T, Union{T, typeof(UNMATCHED)}},
    distance::Dict{Union{T, typeof(UNMATCHED)}, Float64},
)::Bool where {T <: Integer}
    # Initialize queue with the unmatched nodes in set1
    queue = Vector{Union{eltype(graph), typeof(UNMATCHED)}}(
        [n for n in set1 if matching[n] == UNMATCHED]
    )

    distance[UNMATCHED] = Inf
    for n in set1
        if matching[n] == UNMATCHED
            distance[n] = 0.0
        else
            distance[n] = Inf
        end
    end

    while !isempty(queue)
        n1 = popfirst!(queue)

        # If n1 is (a) matched or (b) in set1
        if distance[n1] < Inf && n1 != UNMATCHED
            for n2 in neighbors(graph, n1)
                # If n2 has not been encountered
                if distance[matching[n2]] == Inf
                    # Give it a distance
                    distance[matching[n2]] = distance[n1] + 1

                    # Note that n2 could be unmatched
                    push!(queue, matching[n2])
                end
            end
        end
    end

    found_augmenting_path = (distance[UNMATCHED] < Inf)
    # The distance to UNMATCHED is the length of the shortest augmenting path
    return found_augmenting_path
end

"""
Compute augmenting paths and update the matching
"""
function _hk_augmenting_dfs!(
    graph::Graph{T},
    root::Union{T, typeof(UNMATCHED)},
    matching::Dict{T, Union{T, typeof(UNMATCHED)}},
    distance::Dict{Union{T, typeof(UNMATCHED)}, Float64},
)::Bool where {T <: Integer}
    if root != UNMATCHED
        for n in neighbors(graph, root)
            # Traverse edges of the minimum-length alternating path
            if distance[matching[n]] == distance[root] + 1
                if _hk_augmenting_dfs!(graph, matching[n], matching, distance)
                    # If the edge is part of an augmenting path, update the
                    # matching
                    matching[root] = n
                    matching[n] = root
                    return true
                end
            end
        end
        # If we could not find a matched edge that was part of an augmenting
        # path, we need to make sure we don't consider this vertex again
        distance[root] = Inf
        return false
    else
        # Return true to indicate that we are part of an augmenting path
        return true
    end
end

"""
    hopcroft_karp_matching(graph::Graph)::Dict

Compute a maximum-cardinality matching of a bipartite graph via the
[Hopcroft-Karp algorithm](https://en.wikipedia.org/wiki/Hopcroft-Karp_algorithm).

The return type is a dict mapping nodes to nodes. All matched nodes are included
as keys. For example, if `i` is matched with `j`, `i => j` and `j => i` are both
included in the returned dict.

### Performance

The algorithms runs in O((m + n)n^0.5), where n is the number of vertices and
m is the number of edges. As it does not assume the number of edges is O(n^2),
this algorithm is particularly effective for sparse bipartite graphs.

### Arguments

* `graph`: The bipartite `Graph` for which a maximum matching is computed

### Exceptions

* `ArgumentError`: The provided graph is not bipartite

"""
function hopcroft_karp_matching(graph::Graph)::Dict{Int, Int}
    bmap = bipartite_map(graph)
    if length(bmap) != nv(graph)
        throw(ArgumentError("Provided graph is not bipartite"))
    end
    set1 = [n for n in vertices(graph) if bmap[n] == 1]

    # Initialize "state" that is modified during the algorithm
    matching = Dict{eltype(graph), Union{eltype(graph), typeof(UNMATCHED)}}(
        n => UNMATCHED for n in vertices(graph)
    )
    distance = Dict{Union{eltype(graph), typeof(UNMATCHED)}, Float64}()

    # BFS to determine whether any augmenting paths exist
    while _hk_augmenting_bfs!(graph, set1, matching, distance)
        for n1 in set1
            if matching[n1] == UNMATCHED
                # DFS to update the matching along a minimum-length
                # augmenting path
                _hk_augmenting_dfs!(graph, n1, matching, distance)
            end
        end
    end
    matching = Dict(i => j for (i, j) in matching if j != UNMATCHED)
    return matching
end

function maximum_cardinality_matching(
    graph::Graph,
    algorithm::HopcroftKarpAlgorithm,
)::Dict{Int, Int}
    return hopcroft_karp_matching(graph)
end

"""
    maximum_cardinality_matching(
        graph::Graph,
        algorithm::AbstractMaximumMatchingAlgorithm,
    )::Dict{Int, Int}

Compute a maximum-cardinality matching.

The return type is a dict mapping nodes to nodes. All matched nodes are included
as keys. For example, if `i` is matched with `j`, `i => j` and `j => i` are both
included in the returned dict.

### Arguments

* `graph`: The `Graph` for which a maximum matching is computed

* `algorithm`: The algorithm to use to compute the matching. Default is
  `HopcroftKarpAlgorithm`.

### Algorithms
Currently implemented algorithms are:

* Hopcroft-Karp

### Exceptions

* `ArgumentError`: The provided graph is not bipartite but an algorithm that
  only applies to bipartite graphs, e.g. Hopcroft-Karp, was chosen

### Example
```jldoctest
julia> using Graphs

julia> g = path_graph(6)
{6, 5} undirected simple Int64 graph

julia> maximum_cardinality_matching(g)
Dict{Int64, Int64} with 6 entries:
  5 => 6
  4 => 3
  6 => 5
  2 => 1
  3 => 4
  1 => 2

```
"""
function maximum_cardinality_matching(
    graph::Graph;
    algorithm::AbstractMaximumMatchingAlgorithm = HopcroftKarpAlgorithm(),
)::Dict{Int, Int}
    return maximum_cardinality_matching(graph, algorithm)
end
