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
	write_h2_gen(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the different values of hydrogen generated by the different technologies in operation.
"""
function write_h2_gen(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfH2Gen = inputs["dfH2Gen"]
	H = inputs["H2_RES_ALL"]     # Number of resources (generators, storage, DR, and DERs)
	T = inputs["T"]     # Number of time steps (hours)

	# Hydrogen injected by each resource in each time step
	# dfH2GenOut_annual = DataFrame(Resource = inputs["H2_RESOURCES_NAME"], Zone = dfH2Gen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, H))
	dfH2GenOut = DataFrame(Resource = inputs["H2_RESOURCES_NAME"], Zone = dfH2Gen[!,:Zone], AnnualSum = Array{Union{Missing,Float32}}(undef, H))

	for i in 1:H
		dfH2GenOut[!,:AnnualSum][i] = sum(inputs["omega"].* (value.(EP[:vH2Gen])[i,:]))
	end
	# Load hourly values
	dfH2GenOut = hcat(dfH2GenOut, DataFrame((value.(EP[:vH2Gen])), :auto))

	# Add labels
	auxNew_Names=[Symbol("Resource");Symbol("Zone");Symbol("AnnualSum");[Symbol("t$t") for t in 1:T]]
	rename!(dfH2GenOut,auxNew_Names)

	total = DataFrame(["Total" 0 sum(dfH2GenOut[!,:AnnualSum]) fill(0.0, (1,T))], :auto)

	for t in  1:T
		total[:,t+3] .= sum(dfH2GenOut[:,Symbol("t$t")][1:H])
	end

	rename!(total,auxNew_Names)
	dfPower = vcat(dfH2GenOut, total)

 	CSV.write(string(path,sep,"HSC_h2_generation_discharge.csv"), dftranspose(dfH2GenOut, false), writeheader=false)
	
	return dfH2GenOut
end
