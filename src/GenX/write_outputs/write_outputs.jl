"""
DOLPHYN: Decision Optimization for Low-carbon Power and Hydrogen Networks
Copyright (C) 2022,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
	write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

Function (entry-point) for reporting the different output files. From here, onward several other functions are called, each for writing specific output files, like costs, capacities, etc.
"""
function write_outputs(EP::Model, path::AbstractString, setup::Dict, inputs::Dict)

	## Use appropriate directory separator depending on Mac or Windows config
	if Sys.isunix()
		sep = "/"
    elseif Sys.iswindows()
		sep = "\U005c"
    else
        sep = "/"
	end

    if !haskey(setup, "OverwriteResults") || setup["OverwriteResults"] == 1
        # Overwrite existing results if dir exists
        # This is the default behaviour when there is no flag, to avoid breaking existing code
        if !(isdir(path))
		    mkdir(path)
	    end
    else
        # Find closest unused ouput directory name and create it
        path = choose_output_dir(path)
        mkdir(path)
    end

	# https://jump.dev/MathOptInterface.jl/v0.9.10/apireference/#MathOptInterface.TerminationStatusCode
	status = termination_status(EP)

	## Check if solved sucessfully - time out is included
	if status != MOI.OPTIMAL && status != MOI.LOCALLY_SOLVED
		if status != MOI.TIME_LIMIT # Model failed to solve, so record solver status and exit
			write_status(path, sep, inputs, setup, EP)
			return
			# Model reached timelimit but failed to find a feasible solution
	#### Aaron Schwartz - Not sure if the below condition is valid anymore. We should revisit ####
		elseif isnan(objective_value(EP))==true
			# Model failed to solve, so record solver status and exit
			write_status(path, sep, inputs, setup, EP)
			return
		end
	end

	write_status(path, sep, inputs, setup, EP)
	elapsed_time_costs = @elapsed write_costs(path, sep, inputs, setup, EP)
	print_and_log("Time elapsed for writing costs is $elapsed_time_costs")
	dfCap = write_capacity(path, sep, inputs, setup, EP)
	dfPower = write_power(path, sep, inputs, setup, EP)
	dfCharge = write_charge(path, sep, inputs, setup, EP)
	elapsed_time_storage = @elapsed write_storage(path, sep, inputs, setup, EP)
	print_and_log("Time elapsed for writing storage is $elapsed_time_storage")
	dfCurtailment = write_curtailment(path, sep, inputs, setup, EP)
	elapsed_time_nse = @elapsed write_nse(path, sep, inputs, setup, EP)
	print_and_log("Time elapsed for writing nse is $elapsed_time_nse")
	elapsed_time_power_balance = @elapsed write_power_balance(path, sep, inputs, setup, EP)
	print_and_log("Time elapsed for writing power balance is $elapsed_time_power_balance")
	if inputs["Z"] > 1
		elapsed_time_flows = @elapsed write_transmission_flows(path, sep, setup, inputs, EP)
		print_and_log("Time elapsed for writing transmission flows is $elapsed_time_flows")
		elapsed_time_losses = @elapsed write_transmission_losses(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing transmission losses is $elapsed_time_losses")
		if setup["NetworkExpansion"] == 1
			elapsed_time_expansion = @elapsed write_nw_expansion(path, sep, inputs, setup, EP)
			print_and_log("Time elapsed for writing network expansion is $elapsed_time_expansion")
		end
	end
	elapsed_time_emissions = @elapsed write_emissions(path, sep, inputs, setup, EP)
	print_and_log("Time elapsed for writing emissions is $elapsed_time_emissions")
	if has_duals(EP) == 1
		elapsed_time_reliability = @elapsed write_reliability(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing reliability is $elapsed_time_reliability")
		elapsed_time_stordual = @elapsed write_storagedual(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing storage duals is $elapsed_time_stordual")
	end

	if setup["UCommit"] >= 1
		elapsed_time_commit = @elapsed write_commit(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing commitment is $elapsed_time_commit")
		elapsed_time_start = @elapsed write_start(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing startup is $elapsed_time_start")
		elapsed_time_shutdown = @elapsed write_shutdown(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing shutdown is $elapsed_time_shutdown")
		if setup["Reserves"] == 1
			elapsed_time_reg = @elapsed write_reg(path, sep, inputs, setup, EP)
			print_and_log("Time elapsed for writing regulation is $elapsed_time_reg")
			elapsed_time_rsv = @elapsed write_rsv(path, sep, inputs, setup, EP)
			print_and_log("Time elapsed for writing reserves is $elapsed_time_rsv")
		end
	end


	# Output additional variables related inter-period energy transfer via storage
	if setup["OperationWrapping"] == 1 && !isempty(inputs["STOR_LONG_DURATION"])
		elapsed_time_lds_init = @elapsed write_opwrap_lds_stor_init(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing lds init is $elapsed_time_lds_init")
		elapsed_time_lds_dstor = @elapsed write_opwrap_lds_dstor(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing lds dstor is $elapsed_time_lds_dstor")
	end

	dfPrice = DataFrame()
	dfEnergyRevenue = DataFrame()
	dfChargingcost = DataFrame()
	dfSubRevenue = DataFrame()
	dfRegSubRevenue = DataFrame()
	if has_duals(EP) == 1
		dfPrice = write_price(path, sep, inputs, setup, EP)
		dfEnergyRevenue = write_energy_revenue(path, sep, inputs, setup, EP, dfPower, dfPrice, dfCharge)
		dfChargingcost = write_charging_cost(path, sep, inputs, dfCharge, dfPrice, dfPower, setup)
		dfSubRevenue, dfRegSubRevenue = write_subsidy_revenue(path, sep, inputs, setup, dfCap, EP)
	end

	elapsed_time_time_weights = @elapsed write_time_weights(path, sep, inputs)
	print_and_log("Time elapsed for writing time weights is $elapsed_time_time_weights")
	dfESR = DataFrame()
	dfESRRev = DataFrame()
	if setup["EnergyShareRequirement"]==1 && has_duals(EP) == 1
		dfESR = write_esr_prices(path, sep, inputs, setup, EP)
		dfESRRev = write_esr_revenue(path, sep, inputs, setup, dfPower, dfESR)
	end
	dfResMar = DataFrame()
	dfResRevenue = DataFrame()
	if setup["CapacityReserveMargin"]==1 && has_duals(EP) == 1
		dfResMar = write_reserve_margin(path, sep, setup, EP)
		elapsed_time_rsv_margin = @elapsed write_reserve_margin_w(path, sep, inputs, setup, EP)
		print_and_log("Time elapsed for writing reserve margin is $elapsed_time_rsv_margin")
		dfResRevenue = write_reserve_margin_revenue(path, sep, inputs, setup, dfPower, dfCharge, dfResMar, dfCap)
		elapsed_time_cap_value = @elapsed write_capacity_value(path, sep, inputs, setup, dfPower, dfCharge, dfResMar, dfCap)
		print_and_log("Time elapsed for writing capacity value is $elapsed_time_cap_value")
	end

	elapsed_time_net_rev = @elapsed write_net_revenue(path, sep, inputs, setup, EP, dfCap, dfESRRev, dfResRevenue, dfChargingcost, dfPower, dfEnergyRevenue, dfSubRevenue, dfRegSubRevenue)
	print_and_log("Time elapsed for writing net revenue is $elapsed_time_net_rev")
	## Print confirmation
	print_and_log("Wrote outputs to $path$sep")

	return path

end # END output()
