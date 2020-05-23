include("KernelMatrix.jl")
using DelimitedFiles: writedlm;
using InteractiveUtils: @code_warntype;


function bench(Kernel::AbstractKernel{T}, n::Array{Int64, 1}, verbose::Bool = true) where {T}
  times::Array{Float64, 1} = zeros(Float64, length(n))
  for i in 1:length(n)
    _times::Array{Float64, 1} = zeros(Float64, 3)
    data = rand(T, (784, n[i]))
    for j in 1:3
      t1 = time()
      mat = calculateKernelMatrix(Kernel, data);
      t2 = time()
      _times[j] = t2 - t1
    end
    times[i] = (_times[1] + _times[2] + _times[3])/3
    if verbose
      println("Average time for n = ", n[i], ", ", times[i], " seconds.")
      println("Detailed times: ", _times);
    end
  end
  return times
end

# benchKernel(DotProduct{Float32}(), [1000, 5000, 10_000])
function benchKernel(Kernel::AbstractKernel{T}, n::Array{Int64, 1}, verbose::Bool = true) where {T}
  precompile(kernel, (typeof(Kernel), Array{T, 1}, Array{T, 1}))
  precompile(calculateKernelMatrix, (typeof(Kernel), Array{T, 2}))
  precompile(bench, (typeof(Kernel), Array{Int64, 1}))
  
  times = bench(Kernel, n)
  if verbose
    println("\n\nBenchmark for kernel: ", repr(Kernel), "\ntimes: ", times)
  end

  return (n, times)
end

function runKernelBenchmarks(kernels::NTuple{N, AbstractKernel{T}}, n::Array{Int64, 1}, verbose::Bool = true) where {N, T}
  results = Array{Tuple{Array{Int64, 1}, Array{Float64, 1}}, 1}(undef, length(kernels))
  for i in 1:length(results)
    if verbose # to check types are known at compililation
      @code_warntype benchKernel(kernels[i], n, verbose)
    end
    results[i] = benchKernel(kernels[i], n, verbose)
  end
  return results
end

function main(::Type{T}) where {T}
  n = [1000, 5000 , 10_000, 20_000, 30_000];
  
  kernels = (DotProduct{T}(),   Gaussian{T}(1), Polynomial{T}(2.5, 1),
             Exponential{T}(1), Log{T}(3),      Cauchy{T}(1),
             Power{T}(2.5),     Wave{T}(1),     Sigmoid{T}(1, 1));
  kernelNames = ["DotProduct",  "Gaussian", "Polynomial",
                 "Exponential", "Log",      "Cauchy",
                 "Power",       "Wave",     "Sigmoid"];
  outputs = runKernelBenchmarks(kernels, n)
  
  table = Array{String, 2}(undef, (length(n)*length(kernels) + 1, 4))
  table[1, :] = ["language", "kernel", "nitems", "time"]
  while true
    k = 2
    for i in 1:length(kernelNames)
      tmp = ["Julia", kernelNames[i], "", ""]
      for j in 1:length(n)
        tmp[3] = repr(outputs[i][1][j])
        tmp[4] = repr(outputs[i][2][j])
        table[k, :] = tmp
        k += 1
      end
    end
    if k > size(table)[2]
      break
    end
  end
  
  writedlm("../data/juliaBench.csv", table, ',')
  
  return
end

#=
  To run:
  julia script.jl
  bench: [0.01053166389465332, 0.3132596015930176, 2.171336015065511, 11.15370806058248, 29.200666030248005]
=#
main(Float32)
