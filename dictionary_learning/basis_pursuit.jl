# Atoms: one atom per column
# Signal: signal, as a column vector
using DataFrames
using Gadfly


function normalize_dictionary(dictionary)
    dictionary ./ sqrt(sum(dictionary .^ 2, 1))
end

# Like findmax but works on the absolute value
function find_abs_max(itr)
    i = indmax(abs(itr))
    return (i, itr[i])
end

function matching_persuit(signal, dictionary, sparsity)
    residual = copy(signal)
    to_return = zeros(size(dictionary)[2])

    for i = 1:sparsity
        dots = dictionary' * residual
        (best_atom_index, best_dot_product) = find_abs_max(dots)
        to_return[best_atom_index] += best_dot_product
        residual = residual - (best_dot_product .* dictionary[:,best_atom_index])
    end

    return to_return
end

# Works as above, but updates the residual at each step to
# be perpendicular to the span of the dictionary items.
function orthogonal_matching_persuit(signal, dictionary, sparsity)
    residual = copy(signal)
    num_atoms = size(dictionary)[2]

    orthonormal_basis = zeros(length(signal), sparsity)
    atom_indexes = zeros(sparsity)

    for i = 1:sparsity
        dots = dictionary' * residual
        (best_atom_index, best_dot) = find_abs_max(dots)
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
    return to_return
end


function get_sparse_encoding(signals, dictionary, sparsity)
    num_atoms = size(dictionary)[2]
    num_signals = size(signals)[2]

    encodings = zeros((num_atoms, num_signals))

    for i = 1:num_signals
        encodings[:,i] = orthogonal_matching_persuit(signals[:,i], dictionary, sparsity)
    end
    encodings
end


function k_svd(signals, num_iters, num_atoms, sparsity)
    (signal_dimension, num_signals) = size(signals)

    dictionary = normalize_dictionary(rand(signal_dimension, num_atoms) .- .5)

    atom_indexes = [1:num_atoms]

    best_dict = copy(dictionary)
    best_residual_norm = 100000

    for i = 1:num_iters
        encodings = get_sparse_encoding(signals, dictionary, sparsity)
        total_residual = signals - dictionary * encodings
        residual_norm = norm(total_residual)
        if i % 2 == 0
	    println("Total residual: ", residual_norm, " step: ", i)
        end
        # Can randomize here to not always optimize the signals in the same order
        shuffle!(atom_indexes)
        for k = atom_indexes
            signals_using_atom = find(encodings[k,:])
	    if length(signals_using_atom) == 0
	        continue
	    end
            # We find the residual as if we didn't even have that atom
            restricted_residual = total_residual[:,signals_using_atom] + dictionary[:,k] * encodings[k, signals_using_atom]
            # Now we want to find a new atom that best captures those signals
            (U, s, V) = svd(restricted_residual)
            dictionary[:,k] = U[:,1]
            encodings[k, signals_using_atom] = s[1] * (V')[1,:]
            total_residual[:,signals_using_atom] = restricted_residual - dictionary[:,k] * encodings[k, signals_using_atom]
        end
    end
    dictionary
end

function generate_data(num_signals, signal_dimension, num_sin_waves, noise_level)
    x = linspace(0, 2*pi, signal_dimension)

    basis_waves = [sin(rand() .+ x .* (2*num_signals*rand())) for i in 1:num_sin_waves]
    basis_waves = hcat(basis_waves...)

    selector_matrix = rand(num_sin_waves, num_signals)
    
    return basis_waves * selector_matrix + (noise_level .* rand(signal_dimension, num_signals))
end

function draw_info(signal, dictionary, sparsity)
    x = linspace(0,1,length(signal))
    encoding = orthogonal_matching_persuit(signal, dictionary, sparsity)
    basis_frames = [DataFrame(x=x, y=D[:,i], label="basis_$(i)") for i in find(encoding)]
    encoded_vector = DataFrame(x=x, y=D*encoding, label="approximation")
    raw_signal = DataFrame(x=x, y=signal, label="raw_signal")
    all_frames = vcat(encoded_vector, raw_signal, basis_frames...)
    plot(all_frames, x="x", y="y", color="label", Geom.line)
end

# DEMO #
# SPARSITY = 5
# S = generate_data(300, 100, SPARSITY, .2);
# D = k_svd(S, 200, 80, SPARSITY);
# draw_info(S[:,41], D, SPARSITY)
