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
	write_charge(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the charging energy values of the different storage technologies.
"""
function write_charge(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)
	# Power withdrawn to charge each resource in each time step
	dfCharge = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, G))
	charge = zeros(G,T)
	for i in 1:G
		if setup["ParameterScale"] ==1
			if i in inputs["STOR_ALL"]
				charge[i,:] = value.(EP[:vCHARGE])[i,:] * ModelScalingFactor
			elseif i in inputs["FLEX"]
				charge[i,:] = value.(EP[:vCHARGE_FLEX])[i,:] * ModelScalingFactor
			end
		else
			if i in inputs["STOR_ALL"]
				charge[i,:] = value.(EP[:vCHARGE])[i,:]
			elseif i in inputs["FLEX"]
				charge[i,:] = value.(EP[:vCHARGE_FLEX])[i,:]
			end
		end
		dfCharge[!,:AnnualSum][i] = sum(inputs["omega"].* charge[i,:])
	end
	dfCharge = hcat(dfCharge, DataFrame(charge, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfCharge,auxNew_Names)
	total = DataFrame(["Total" 0 sum(dfCharge[!,:AnnualSum]) fill(0.0, (1,T))], :auto)
	for t in 1:T
		if v"1.3" <= VERSION < v"1.4"
			total[!,t+3] .= sum(dfCharge[!,Symbol("t$t")][union(inputs["STOR_ALL"],inputs["FLEX"])])
		elseif v"1.4" <= VERSION < v"1.9"
			total[:,t+3] .= sum(dfCharge[:,Symbol("t$t")][union(inputs["STOR_ALL"],inputs["FLEX"])])
		end
	end
	rename!(total,auxNew_Names)
	dfCharge = vcat(dfCharge, total)
	CSV.write(string(path,sep,"charge.csv"), dftranspose(dfCharge, false), writeheader=false)
	return dfCharge
end
