using Distributions
using Random

function main()
    d = Normal()
    Threads.@threads for j in 1:10
        my_thread_id = Threads.threadid()
        x = rand(d)
        println("Thread $my_thread_id: j=$j: x=$x")
        sleep(5.0)
    end
end

main()

