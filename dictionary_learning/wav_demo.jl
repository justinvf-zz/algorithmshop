using WAV

FILENAME = "british_speaking.wav"

require("k_svd")

wav, FS = wavread(FILENAME)

midpoint = int(size(wav)[1]/2)

# We want to build a dictionary off of the first half of the file
# to see how well we can emulate the sound in the second half of the file

function training_data(num_samples, sample_dimension)
    max_index = int(size(wav)[1] / 2 - sample_dimension)
    starting_values = rand(1:max_index, num_samples)
    data = [wav[i:(i+sample_dimension-1)] for i in starting_values]

    hcat(data...)
end

function encode_half_2(D, sparsity, seconds=8)
    sample_length = size(D)[1]
    output = zeros(seconds * FS)
    num_frames = int(seconds * FS / sample_length)
    for i = 0:(num_frames-1)
        start_offset = i*sample_length
        end_offset = start_offset + sample_length
        signal_piece = wav[midpoint + start_offset:midpoint + end_offset-1]
        sparse_encoding = orthogonal_matching_persuit(signal_piece, D, sparsity)
        sparsely_encoded = D*sparse_encoding
        output[start_offset+1:end_offset] = sparsely_encoded
    end
    output /= maximum(abs(output[:,1]))
    wavwrite(wav[midpoint:end], "original_second_half.wav", Fs=FS)
    wavwrite(output, "encoded_second_half.wav", Fs=FS)
end

function demo()
    S = training_data(1000, 200);
    sparsity = 40
    # Slow step...
    D = k_svd(S, 30, 500, sparsity);
    encode_half_2(D, sparsity)
end
