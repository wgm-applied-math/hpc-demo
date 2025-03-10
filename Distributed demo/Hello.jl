#!/usr/bin/env julia

using Distributed
using SlurmClusterManager

addprocs(SlurmManager())

@everywhere begin
    println("Hello from process $(myid()) on $(gethostname())")
    sleep(30)
    println("Goodbye from process $(myid()) on $(gethostname())")
end
