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


# Works sorta like matching_persuit, but updates the residual at each step to
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
        # residual orthogonal to the subspace. At the end of the algorithm
        # we solve the signal in terms of the chosen vectors.
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
    # Least squares solve with the chosen atoms
    final_coords = final_atoms \ signal
    # create the vector with the specified sparsity
    to_return = zeros(num_atoms)
    for (atom_index, atom_coord) in zip(atom_indexes, final_coords)
        to_return[atom_index] = atom_coord
    end
    to_return
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


# Given signals (each sample a column vector), this will
# iteratively refine a dictionary that can reproduce the signals
# with a given degree of sparsity (l_0 norm of the encoding vectors)
function k_svd(signals, num_iters, num_atoms, sparsity)
    dictionary = normalize_dictionary(rand(signal_dimension, num_atoms) .- .5)
    k_svd(signals, num_iters, num_atoms, sparsity, dictionary)
end


# Work with a dictionary that aready exists (possibly to further refine it).
function k_svd(signals, num_iters, num_atoms, sparsity, dictionary)
    (signal_dimension, num_signals) = size(signals)

    # We will randomly change the order that we visit atoms
    # in the ksvd step
    atom_indexes = [1:num_atoms]
    last_print = 0
    residual_norm = 0

    for i = 1:num_iters
        encodings = get_sparse_encoding(signals, dictionary, sparsity)
        total_residual = signals - dictionary * encodings
        residual_norm = norm(total_residual)
        if time() - last_print > 10
	    println("Total residual: ", residual_norm, " step: ", i)
            last_print = time()
        end
        # Can randomize here to not always optimize the signals in the same order
        shuffle!(atom_indexes)
        for k = atom_indexes
            signals_using_atom = find(encodings[k,:])
	    if length(signals_using_atom) == 0
	        continue
	    end
            # We find the residual as if we didn't even have that atom (so add it back in)
            restricted_residual = total_residual[:,signals_using_atom] + dictionary[:,k] * encodings[k, signals_using_atom]
            # Now we want to find a new atom that best captures that residual
            (U, s, V) = svd(restricted_residual)
            # First singular value is the one that most captures the residual. Set this as the new atom
            dictionary[:,k] = U[:,1]
            # The right hand side here is the length of the projection onto the first singualar value,
            # which is precisely the encoding.
            encodings[k, signals_using_atom] = s[1] * (V')[1,:]
            # We removed the original atom from the residual above. Now we update the total residual
            # by subtracting out the result of this new encoding from the residual
            total_residual[:,signals_using_atom] = restricted_residual - dictionary[:,k] * encodings[k, signals_using_atom]
        end
    end
    dictionary
end


# Generate some fake data from combinations of noised up sin waves
function generate_data(num_signals, signal_dimension, num_sin_waves, noise_level)
    x = linspace(0, 2*pi, signal_dimension)

    basis_waves = [sin(rand() .+ x .* (2*num_signals*rand())) for i in 1:num_sin_waves]
    basis_waves = hcat(basis_waves...)

    selector_matrix = rand(num_sin_waves, num_signals)
    
    return basis_waves * selector_matrix + (noise_level .* rand(signal_dimension, num_signals))
end


# Plot the signal, the sparse approximation, and the basis functions used
# in the sparse approximation
function draw_info(signal, dictionary, sparsity)
    x = linspace(0,1,length(signal))
    encoding = orthogonal_matching_persuit(signal, dictionary, sparsity)
    basis_frames = [DataFrame(x=x, y=D[:,i], label="basis_$(i)") for i in find(encoding)]
    encoded_vector = DataFrame(x=x, y=D*encoding, label="approximation")
    raw_signal = DataFrame(x=x, y=signal, label="raw_signal")
    all_frames = vcat(encoded_vector, raw_signal, basis_frames...)
    plot(all_frames, x="x", y="y", color="label", Geom.line)
end


# Generates some fake data, fits a dictionary, and then graphs
# how the sparse approximation of the signal looks compared to
# the signal.
function demo()
    sparsity = 5
    S = generate_data(300, 100, sparsity, .2);
    D = k_svd(S, 200, 80, sparsity);
    draw_info(S[:,41], D, sparsity)
end
