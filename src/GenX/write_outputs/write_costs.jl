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
	write_costs(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting the costs pertaining to the objective function (fixed, variable O&M etc.).
"""
function write_costs(path::AbstractString, sep::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	## Cost results
	dfGen = inputs["dfGen"]
	SEG = inputs["SEG"]  # Number of lines
	Z = inputs["Z"]     # Number of zones
	T = inputs["T"]     # Number of time steps (hours)

	dfCost = DataFrame(Costs = ["cTotal", "cFix", "cVar", "cNSE", "cStart", "cUnmetRsv", "cNetworkExp"])
	if setup["ParameterScale"] == 1
		cVar = (value(EP[:eTotalCVarOut])+ (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0) + (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0)) * (ModelScalingFactor^2)
		cFix = (value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0)) * (ModelScalingFactor^2)
		cNSE =  value(EP[:eTotalCNSE]) * (ModelScalingFactor^2)
		#cTotal = cVar + cFix + cNSE
		#dfCost[!,Symbol("Total")] = [cTotal, cFix, cVar, cNSE, 0, 0, 0]
	else
		cVar = (value(EP[:eTotalCVarOut])+ (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0) + (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0))
		#cVar = value(EP[:eTotalCVarOut])+(!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCVarIn]) : 0) + (!isempty(inputs["FLEX"]) ? value(EP[:eTotalCVarFlexIn]) : 0)
		cFix = value(EP[:eTotalCFix]) + (!isempty(inputs["STOR_ALL"]) ? value(EP[:eTotalCFixEnergy]) : 0) + (!isempty(inputs["STOR_ASYMMETRIC"]) ? value(EP[:eTotalCFixCharge]) : 0)
		cNSE = value(EP[:eTotalCNSE])
		#cTotal = cVar + cFix + cNSE
	end

	# Adding emissions penalty to variable cost depending on type of emissions policy constraint
	# Emissions penalty is already scaled by adjusting the value of carbon price used in emissions_HSC.jl
	if setup["CO2Cap"]==4
		cVar  = cVar + value(EP[:eCGenTotalEmissionsPenalty])
	end

	# Start cost
	if setup["UCommit"]>=1
		if setup["ParameterScale"] == 1
			cStartCost = value(EP[:eTotalCStart]) * (ModelScalingFactor^2)
		else
			cStartCost = value(EP[:eTotalCStart])
		end
	else
		cStartCost =0
		#cTotal += dfCost[!,2][5]
	end

	# Reserve cost
	if setup["Reserves"]==1
		if setup["ParameterScale"] == 1
			cRsvCost = value(EP[:eTotalCRsvPen]) * (ModelScalingFactor^2)
		else
			cRsvCost = value(EP[:eTotalCRsvPen])
		end
	else
		cRsvCost = 0
		#cTotal += dfCost[!,2][6]
	end

	# Network expansion cost
	if setup["NetworkExpansion"] == 1 && Z > 1
		if setup["ParameterScale"] == 1
			cNetworkExpansionCost = value(EP[:eTotalCNetworkExp]) * (ModelScalingFactor^2)
		else
			cNetworkExpansionCost = value(EP[:eTotalCNetworkExp])
		end

	else
		cNetworkExpansionCost =0
		#cTotal += dfCost[!,2][7]
	end

	# Define total costs
	cTotal = cFix + cVar + cNSE + cStartCost+ cRsvCost+cNetworkExpansionCost

	# Define total column, i.e. column 2
	dfCost[!,Symbol("Total")] = [cTotal, cFix, cVar, cNSE, cStartCost, cRsvCost, cNetworkExpansionCost]

	# Computing zonal cost breakdown by cost category
	for z in 1:Z
		tempCTotal = 0
		tempCFix = 0
		tempCVar = 0
		tempCStart = 0
		for y in dfGen[dfGen[!,:Zone].==z,:][!,:R_ID]
			tempCFix = tempCFix +
				(y in inputs["STOR_ALL"] ? value.(EP[:eCFixEnergy])[y] : 0) +
				(y in inputs["STOR_ASYMMETRIC"] ? value.(EP[:eCFixCharge])[y] : 0) +
				value.(EP[:eCFix])[y]
			tempCVar = tempCVar +
				(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
				(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
				sum(value.(EP[:eCVar_out])[y,:])
			if setup["UCommit"]>=1
				tempCTotal = tempCTotal +
					value.(EP[:eCFix])[y] +
					(y in inputs["STOR_ALL"] ? value.(EP[:eCFixEnergy])[y] : 0) +
					(y in inputs["STOR_ASYMMETRIC"] ? value.(EP[:eCFixCharge])[y] : 0) +
					(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
					(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
					sum(value.(EP[:eCVar_out])[y,:]) +
					(y in inputs["COMMIT"] ? sum(value.(EP[:eCStart])[y,:]) : 0)
					#
				tempCStart = tempCStart +
					(y in inputs["COMMIT"] ? sum(value.(EP[:eCStart])[y,:]) : 0)
			else
				tempCTotal = tempCTotal +
					value.(EP[:eCFix])[y] +
					(y in inputs["STOR_ALL"] ? value.(EP[:eCFixEnergy])[y] : 0) +
					(y in inputs["STOR_ASYMMETRIC"] ? value.(EP[:eCFixCharge])[y] : 0) +
					(y in inputs["STOR_ALL"] ? sum(value.(EP[:eCVar_in])[y,:]) : 0) +
					(y in inputs["FLEX"] ? sum(value.(EP[:eCVarFlex_in])[y,:]) : 0) +
					sum(value.(EP[:eCVar_out])[y,:])
			end
		end

		if setup["ParameterScale"] == 1
			tempCFix = tempCFix * (ModelScalingFactor^2)
			tempCVar = tempCVar * (ModelScalingFactor^2)
			tempCTotal = tempCTotal * (ModelScalingFactor^2)
			tempCStart = tempCStart * (ModelScalingFactor^2)
		end

		# Add emisions penalty related costs if the constraints are active to variable and total costs
		# Emissions penalty is already scaled previously depending on value of ParameterScale and hence not scaled here
		if setup["CO2Cap"]==4
			tempCVar  = tempCVar + value.(EP[:eCEmissionsPenaltybyZone])[z]
			tempCTotal=tempCTotal + value.(EP[:eCEmissionsPenaltybyZone])[z]
		end

		if setup["ParameterScale"] == 1
			tempCNSE = sum(value.(EP[:eCNSE])[:,:,z]) * (ModelScalingFactor^2)
		else
			tempCNSE = sum(value.(EP[:eCNSE])[:,:,z])
		end
		# Update non-served energy cost for each zone
		tempCTotal = tempCTotal +tempCNSE

		dfCost[!,Symbol("Zone$z")] = [tempCTotal, tempCFix, tempCVar, tempCNSE, tempCStart, "-", "-"]
	end
	CSV.write(string(path,sep,"costs.csv"), dfCost)
end
