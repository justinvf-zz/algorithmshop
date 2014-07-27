
# Atoms: one atom per column
# Signal: signal, as a column vector

function normalize_dictionary(D)
    D ./ sqrt(sum(D .^ 2, 1))
end

# Like findmax but works on the absolute value
function find_abs_max(itr)
    i = indmax(abs(itr))
    return (i, itr[i])
end

function matching_persuit(atoms, signal, max_l0)
    residual = copy(signal)
    to_return = zeros(size(atoms)[2])

    for i = 1:(max_l0)
        dots = atoms' * residual
        (best_atom_index, best_dot_product) = find_abs_max(dots)
        to_return[best_atom_index] += best_dot_product
        residual = residual - (best_dot_product .* atoms[:,best_atom_index])
    end

    return to_return
end

# Works as above, but updates the residual at each step to
# be perpendicular to the span of the dictionary items.
function othogonal_matching_persuit(dictionary, signal, max_l0)
    residual = copy(signal)
    num_atoms = size(dictionary)[2]

    orthonormal_basis = zeros(length(signal), max_l0)
    atom_indexes = zeros(max_l0)

    for i = 1:(max_l0)
        dots = dictionary' * residual
        best_atom_index = indmax(dots)
        atom_indexes[i] = best_atom_index

        # We are going to add this new best atom to our growing subspace.
        # We want to update the residual though to just be the component of
        # residual orthogonal to the subspace. Later we will go back and
        # find the actual atom coeeficients.
        orthogonalized_atom = copy(dictionary[:,best_atom_index])
        for j = 1:(i-1)
            basis_vec = orthonormal_basis[:,j]
            orthogonalized_atom -= dot(basis_vec, orthogonalized_atom) .* basis_vec
        end
        orthogonalized_atom /= norm(orthogonalized_atom)
        orthonormal_basis[:,i] = orthogonalized_atom
        residual = residual - (dot(orthogonalized_atom, residual) .* orthogonalized_atom)
    end

    final_atoms = dictionary[:,atom_indexes]
    final_coords = final_atoms \ signal
    to_return = zeros(num_atoms)
    for i = 1:length(atom_indexes)
        to_return[atom_indexes[i]] = final_coords[i]
    end
    #println("FINAL DISTANCE : ", norm(atoms * to_return - signal))
    return to_return
end

function get_sparse_encoding(signals, dictionary, sparsity)
    num_atoms = size(dictionary)[2]
    num_signals = size(signals)[2]

    encodings = zeros((num_atoms, num_signals))

    for i = 1:num_signals
        encodings[:,i] = orthogonal_matching_persuit(dictionary, signals[:,i], sparsity)
    end
    encodings
end

function k_svd(signals, num_iters, num_atoms, sparsity)
    (signal_dimension, num_signals) = size(signals)

    dictionary = normalize_dictionary(rand(signal_dimension, num_atoms))

    for i = 1:num_iters
        encodings =  get_sparse_encoding(signals, dictionary, sparsity)
        total_residual = signals - dictionary * encodings

        # Can randomize here to not always optimize the signals in the same order
        for k = 1:num_atoms
            signals_using_atom = find(encodings[k,:])
            # We find the residual as if we didn't even have that atom
            restricted_residual = total_residual[:,signals_using_atom] + dictionary[:,k] * encodings[k, signals_using_atom]
            # Now we want to find a new atom that best captures those signals
            (U, s, V) = svd(restricted_residual)
            dictionary[:,k] = U
            encodings[k, signals_using_atom] = s[1] * (V')[1,:]
        end
        # (U, s, V) = svd(residual_for_k)
        # new_k = U[:,1]
        # best_projection_onto_new_k = U[:,1] * s[1] * (V')[1,:]
    end
    dictionary
end
