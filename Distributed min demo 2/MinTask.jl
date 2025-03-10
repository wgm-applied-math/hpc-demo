#!/usr/bin/env julia

using Distributed
using RandomNumbers, Random123
using SlurmClusterManager

# Create processes according to the SLURM environment variables
addprocs(SlurmManager(), exeflags="--threads=$(ENV["SLURM_CPUS_PER_TASK"]) --project=@.")

@everywhere begin
    using Random
    
    function seek_min(jobs, results)
        println("Hello from process $(myid()) on $(gethostname()) nthreads = $(Threads.nthreads()) project = $(Base.active_project())")
        flush(stdout)
        while true
            println("Process $(myid()) on $(gethostname()) requesting job")
            flush(stdout)
            s = take!(jobs)        
            println("Process $(myid()) on $(gethostname()) took job $s")
            flush(stdout)        
            println("Process $(myid()) on $(gethostname()) working on seed $s")
            flush(stdout)
            Random.seed!(s)
            xs = zeros(10)
            Threads.@threads for j in 1:length(xs)
                # make normally distributed random numbers and take the minimum
                xs[j] = minimum(randn(10))
            end
            # pick out the grand minimum
            x_min = minimum(xs)
            println("Process $(myid()) on $(gethostname()) sending $x_min")
            put!(results, (myid(), s, x_min))
        end
    end
end

const NJobs = 20
const CSize = 100
# Jobs are random number generator seeds
jobs = RemoteChannel(()->Channel{UInt64}(CSize))
results = RemoteChannel(()->Channel{Tuple}(CSize))

function make_jobs(n)
    # Going to try a counter/hash random number generator
    # to generate what I hope are nearly-independent seeds.
    g = Philox2x(8500)
    for j in 1:n
        s = rand(g, UInt64)
        println("About to put job $s into channel")
        flush(stdout)
        put!(jobs, s)
        println("Just put job $s into channel")
        flush(stdout)
    end
end

println("About to call make_jobs")
flush(stdout)
errormonitor(@async make_jobs(NJobs))
println("Called make_jobs")
flush(stdout)


for p in workers()
    remote_do(seek_min, p, jobs, results)
end

function collect_results(n)
    taken_results = Float64[]
    while n > 0
        println("About to take result, n = $n")
        flush(stdout)
        worker_id, s, x_min = take!(results)
        println("Result: process $worker_id finished with seed $s, found $x_min")
        flush(stdout)
        push!(taken_results, x_min)
        n = n - 1
    end
    println("Results collected")
    sorted_results = sort(taken_results)
    @show sorted_results
    flush(stdout)
end

# -- MAIN --

println("SLURM_JOBID = $(ENV["SLURM_JOBID"])")
println("SLURM_NTASKS = $(ENV["SLURM_NTASKS"])")
println("nthreads = $(Threads.nthreads())")
flush(stdout)

collect_results(NJobs)
