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
	write_esr_prices(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting prices under energy share requirements.	
"""
function write_esr_prices(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	
	dfESR = DataFrame(ESR_Price = convert(Array{Union{Missing, Float64}}, dual.(EP[:cESRShare])))
	
	if setup["ParameterScale"] == 1
		dfESR[!,:ESR_Price] = dfESR[!,:ESR_Price] * ModelScalingFactor # Converting MillionUS$/GWh to US$/MWh
	end
	
	CSV.write(string(path,sep,"ESR_prices.csv"), dfESR)
	
	return dfESR
end
