using Plots, Distributions, Plots.Measures, StatsPlots

function update_gold_diff(win_prob,gold_diff)
    alpha = 1.25
    constant_term = 300 * (win_prob-0.5)^alpha
    if gold_diff > 0 
        snowball_term = 0.1 * abs(gold_diff) * (win_prob+0.5)^alpha
    else
        snowball_term = -0.1 * abs(gold_diff) / (win_prob+0.5)^alpha
    end
    mean = constant_term + snowball_term
    stddev = 420
    return gold_diff + rand(Normal(mean,stddev))
end

function end_game(time,gold_diff)
    if time<15
        return true, nothing
    end
    # as game goes on, relative gold diff becomes less important
    # and chances of either team winning go up
    midpoint = 10000 - time * 100
    L = 0.1 + time/200
    k = 0.0003
    # sigmoid function of gold diff decides probability of immediate win
    pwin =  (L / (1 + exp(k * (-gold_diff + midpoint))))
    plose = (L / (1 + exp(k * (gold_diff + midpoint))))
    if pwin > plose
        if rand() < pwin
            return false, true
        elseif rand() < plose
            return false, false
        end
    else
        if rand() < plose
            return false, false
        elseif rand() < pwin
            return false, true
        end
    end
    return true, nothing
end

function k_format(x)
    if abs(x) >= 1000
        return string(round(Int, x / 1000), "k")
    else
        return string(x)
    end
end

function run_game(win_prob;surrender_threshold=-Inf,showplot=false)
    time = 1
    gold_diff = 0
    game_ongoing = true
    times = [0.0,1.0]
    gds = [0.0,0.0]
    if showplot
        p = plot(times,gds, ylabel="Minutes", xlabel="Gold Difference", 
        title="Gold Difference Over Time", lw=2, color=:blue, 
        ylim=(0,80), xlim=(-15000,15000),size=(600,960),margin = 30mm, 
        xformatter=k_format, legend=false, framestyle = :box, guidefont=font(12))
    end
    win = nothing
    gdat15 = 0
    while game_ongoing
        time += 1
        gold_diff = update_gold_diff(win_prob,gold_diff)
        push!(times,time)
        push!(gds,gold_diff)
        if time == 15
            gdat15 = gold_diff
        end
        # gold_diff = rand(TruncatedNormal(0, 7000,-20000,20000))
        if (gold_diff <  surrender_threshold) && (time >= 15) && (time <= 25)
            game_ongoing = false
            win = false
        else
           game_ongoing, win = end_game(time,gold_diff)
           
        end
        if showplot
            plot!(p,gds,times,legend=false,color=:blue)
            if win !== nothing
                annotation = win ? "Victory" : "Defeat"
                gold_diff = round(Int,gold_diff)
                msg = "Time: $time minutes\nGold Difference: $gold_diff\nResult: $annotation"
                annotate!(p,[(gold_diff,time+5,msg)])
            end
            gui(p)
        end
    end
    return time, win, gdat15
end

function test_game(win_prob;showplot=false)
    times = []
    wins = []
    gold_diffs = []
    wins_from_behind = []
    for i in 1:50000
        time, win, gold_diff = run_game(win_prob)
        push!(times,time)
        push!(wins,win)
        push!(gold_diffs,gold_diff)
    end

    # println("Win rate: ", sum(wins)/length(wins))
    # sleep(3)
    # gui(histogram(gold_diffs, bins=50, xlabel="Gold Difference", ylabel="Frequency", title="Gold Difference Distribution", legend=false, framestyle = :box, guidefont=font(12)))
    winrate = sum(wins)/length(wins)
    avg_game_time = mean(times)
    if showplot
        gd_wins = [gold_diffs[i] for i in 1:length(wins) if wins[i]]
        gd_losses = [gold_diffs[i] for i in 1:length(wins) if !wins[i]]
        println(mean(gd_wins), " ", mean(gd_losses))
        gui(boxplot([gd_wins,gd_losses], xlabel="Result", ylabel="Gold Difference", title="Gold Difference at 15 vs. Game Result", legend=false, framestyle = :box, guidefont=font(12)))
        sleep(4)
        gui(histogram(times, bins=50, xlabel="Game Length (minutes)", ylabel="Frequency", title="Game Length Distribution", legend=false, size=(600,960), margin=10mm, framestyle = :box, guidefont=font(12)))
        println("Win rate: ", winrate)
    end
    return winrate, avg_game_time
end

function metatest()
    winrates = []
    gametimes = []
    for i in 0.5:0.01:0.8
        winrate, gametime = test_game(i)
        push!(winrates,winrate)
        push!(gametimes,gametime)
    end
    
    gui(scatter(0.5:0.01:0.8,winrates, xlabel="Expected winrate", ylabel="Simulated winrate", title="Need this line to be straight corner to corner", xlims=(0.5,0.8), size = (1000,1000), ylims=(0.5,0.8), legend=false, framestyle = :box, guidefont=font(12)))   
    # sleep(4)
    # gui(scatter(winrates,gametimes, xlabel="Winrate", ylabel="Average Game Time", title="Winrate vs. Average Game Time", legend=false, framestyle = :box, guidefont=font(12)))
end

function simulate_season(winrate,surrender_threshold,time_allowed)
    total_time = 0
    lp_gain = 0
    total_games_played = 0
    while total_time < time_allowed
        time, win, gd = run_game(winrate,surrender_threshold=surrender_threshold)
        # add 10 minutes for queue and champ select per game
        total_time += time + 10
        lp_gain += win ? 25 : -25
        total_games_played += 1
    end
    return lp_gain, total_games_played
end

function test_season(winrate,surrender_threshold,time_allowed)
    lp_gains = []
    games_played = []
    for i in 1:5000
        lp, games = simulate_season(winrate,surrender_threshold,time_allowed)
        push!(lp_gains,lp)
        push!(games_played,games)
    end
    return mean(lp_gains)
end

function final_results()
    thresholds = -7000:500:-2000
    tot_mins = 24000
    # thresholds = [-5000,-4000]
    low_ref = test_season(0.53,-500000,tot_mins)
    high_ref = test_season(0.6,-500000,tot_mins)
    smurf_ref = test_season(0.7,-500000,tot_mins)

    low_wr = test_season.(Ref(0.53),thresholds,Ref(tot_mins)) .- low_ref
    high_wr = test_season.(Ref(0.6),thresholds,Ref(tot_mins)) .- high_ref
    smurf_wr = test_season.(Ref(0.7),thresholds,Ref(tot_mins)) .- smurf_ref
    p = scatter(thresholds,low_wr, xlabel="Surrender threshold (gold difference)", ylabel="Difference in LP gains", size=(600,960), ylims = (-1000,500), legend=:topright, margin = 10mm, title="LP Gain vs. Surrender Threshold", label="53%", legendtitle="Expected winrate", framestyle = :box, guidefont=font(12))
    scatter!(p,thresholds,high_wr, label = "60%")
    scatter!(p,thresholds,smurf_wr, label = "75%")
    gui(p)
end