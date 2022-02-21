export
    factor_graph,
    rank_reveal,
    projectors,
    split_into_clusters,
    decode_factor_graph_state,
    energy, cluster_size

"""
$(TYPEDSIGNATURES)

"""
function split_into_clusters(ig::LabelledGraph{S, T}, assignment_rule) where {S, T}
    cluster_id_to_verts = Dict(i => T[] for i in values(assignment_rule))
    for v in vertices(ig)
        push!(cluster_id_to_verts[assignment_rule[v]], v)
    end
    Dict(i => first(cluster(ig, verts)) for (i, verts) ∈ cluster_id_to_verts)
end

"""
$(TYPEDSIGNATURES)

"""
function factor_graph(
    ig::IsingGraph,
    num_states_cl::Int;
    spectrum::Function=full_spectrum,
    cluster_assignment_rule::Dict{Int, T} # e.g. square lattice
) where T
    ns = Dict(i => num_states_cl for i ∈ Set(values(cluster_assignment_rule)))
    factor_graph(ig, ns, spectrum=spectrum, cluster_assignment_rule=cluster_assignment_rule)
end

"""
$(TYPEDSIGNATURES)

"""
function factor_graph(
    ig::IsingGraph,
    num_states_cl::Dict{T, Int};
    spectrum::Function=full_spectrum,
    cluster_assignment_rule::Dict{Int, T}
) where T
    L = maximum(values(cluster_assignment_rule))
    fg = LabelledGraph{MetaDiGraph}(sort(unique(values(cluster_assignment_rule))))

    for (v, cl) ∈ split_into_clusters(ig, cluster_assignment_rule)
        sp = spectrum(cl, num_states=get(num_states_cl, v, basis_size(cl)))
        set_props!(fg, v, Dict(:cluster => cl, :spectrum => sp))
    end

    for (i, v) ∈ enumerate(vertices(fg)), w ∈ vertices(fg)[i+1:end]
        cl1, cl2 = get_prop(fg, v, :cluster), get_prop(fg, w, :cluster)
        outer_edges, J = inter_cluster_edges(ig, cl1, cl2)

        if !isempty(outer_edges)
            ind1 = vec(any(i -> i != 0, J, dims=2))
            ind2 = vec(any(i -> i != 0, J, dims=1))

            JJ = J[ind1, ind2]

            states_v = get_prop(fg, v, :spectrum).states
            states_w = get_prop(fg, w, :spectrum).states

            pl, unique_states_v = rank_reveal([s[ind1] for s ∈ states_v])
            pr, unique_states_w = rank_reveal([s[ind2] for s ∈ states_w])
            en = inter_cluster_energy(unique_states_v, JJ, unique_states_w)

            add_edge!(fg, v, w)
            set_props!(
                fg, v, w, Dict(:outer_edges => outer_edges, :pl => pl, :en => en, :pr => pr)
            )
        end
    end
    fg
end

"""
$(TYPEDSIGNATURES)

"""
function factor_graph(
    ig::IsingGraph; spectrum::Function=full_spectrum, cluster_assignment_rule::Dict{Int, T}
) where T
    factor_graph(
      ig, Dict{T, Int}(), spectrum=spectrum, cluster_assignment_rule=cluster_assignment_rule
    )
end

"""
$(TYPEDSIGNATURES)

"""
function rank_reveal(energy)
    E, idx = unique_dims(energy, 1)
    P = identity.(idx)
    P, E
end

"""
$(TYPEDSIGNATURES)

"""
function decode_factor_graph_state(fg, state::Vector{Int})
    ret = Dict{Int, Int}()
    for (i, vert) ∈ zip(state, vertices(fg))
        spins = get_prop(fg, vert, :cluster).labels
        states = get_prop(fg, vert, :spectrum).states
        if length(states) > 0
            curr_state = states[i]
            merge!(ret, Dict(k => v for (k, v) ∈ zip(spins, curr_state)))
        end
    end
    ret
end

function energy(fg::LabelledGraph{S, T}, σ::Dict{T, Int}) where {S, T}
    en_fg = 0.0
    for v ∈ vertices(fg) en_fg += get_prop(fg, v, :spectrum).energies[σ[v]] end
    for edge ∈ edges(fg)
        pl, pr = get_prop(fg, edge, :pl), get_prop(fg, edge, :pr)
        en = get_prop(fg, edge, :en)
        en_fg += en[pl[σ[src(edge)]], pr[σ[dst(edge)]]]
    end
    en_fg
end

# function cluster_size(factor_graph::LabelledGraph{S, T}, vertex::T) where {S, T}
#     length(get_prop(factor_graph, vertex, :spectrum).energies)
# end
