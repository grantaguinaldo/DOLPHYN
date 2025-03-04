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
	investment_charge(EP::Model, inputs::Dict)

This function defines the expressions and constraints keeping track of total available storage charge capacity ($s \in \mathcal{S}^{asym}, \mathcal{S}^{asym} \subseteq \mathcal{S}$) as well as constraints on capacity retirements.
The function also adds investment and fixed O\&M costs related to charge capacity to the objective function.

The total capacity of each storage resource is defined as the sum of the existing capacity plus the newly invested capacity minus any retired capacity.

```math
\begin{equation*}
	y_{s,z}^{\textrm{E,CHA,total}} = y_{s,z}^{\textrm{E,CHA,existing}} + y_{s,z}^{\textrm{E,CHA,new}} - y_{s,z}^{\textrm{E,CHA,retired}} \quad \forall s \in \mathcal{S}^{asym}, z \in \mathcal{Z}
\end{equation*}
```

**Cost expressions**

In addition, this module adds investment and fixed O\&M costs related to charge capacity to the objective function:
```math
\begin{equation*}
	\textrm{C}^{\textrm{E,CHA,c}} = \sum_{s \in \mathcal{S}^{asym}} \sum_{z \in \mathcal{Z}} (\textrm{c}_{s,z}^{\textrm{E,CHA,INV}} \times y_{s,z}^{\textrm{E,CHA,new}} + \textrm{c}_{s,z}^{\textrm{E,CHA,FOM}} \times y_{s,z}^{\textrm{E,CHA,total}})
\end{equation*}
```

**Constraints on storage charge capacity**

One cannot retire more capacity than existing capacity.
```math
\begin{equation*}
	0 \leq y_{s,z}^{\textrm{E,CHA,retired}} \leq y_{s,z}^{\textrm{E,CHA,existing}} \quad \forall s \in \mathcal{S}^{asym}, z \in \mathcal{Z}
\end{equation*}
```

For storage resources where upper bound $\overline{\textrm{R}}_{s,z}^{\textrm{E,CHA}}$ and lower bound $\underline{\textrm{R}}_{s,z}^{\textrm{E,CHA}}$ is defined, then we impose constraints on minimum and maximum storage charge capacity.

```math
\begin{equation*}
	\underline{\textrm{R}}_{s,z}^{\textrm{E,CHA}} \leq y_{s,z}^{\textrm{E,CHA}} \leq \overline{\textrm{R}}_{s,z}^{\textrm{E,CHA}} \quad \forall s \in \mathcal{S}^{asym}, z \in \mathcal{Z}
\end{equation*}
```
"""
function investment_charge(EP::Model, inputs::Dict)

	print_and_log("Charge Investment Module")

	dfGen = inputs["dfGen"]

	STOR_ASYMMETRIC = inputs["STOR_ASYMMETRIC"] # Set of storage resources with asymmetric (separte) charge/discharge capacity components

	NEW_CAP_CHARGE = inputs["NEW_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for new charge capacity
	RET_CAP_CHARGE = inputs["RET_CAP_CHARGE"] # Set of asymmetric charge/discharge storage resources eligible for charge capacity retirements

	### Variables ###

	## Storage capacity built and retired for storage resources with independent charge and discharge power capacities (STOR=2)

	# New installed charge capacity of resource "y"
	@variable(EP, vCAPCHARGE[y in NEW_CAP_CHARGE] >= 0)

	# Retired charge capacity of resource "y" from existing capacity
	@variable(EP, vRETCAPCHARGE[y in RET_CAP_CHARGE] >= 0)

	### Expressions ###

	@expression(EP, eTotalCapCharge[y in STOR_ASYMMETRIC],
		if (y in intersect(NEW_CAP_CHARGE, RET_CAP_CHARGE))
			dfGen[!,:Existing_Charge_Cap_MW][y] + EP[:vCAPCHARGE][y] - EP[:vRETCAPCHARGE][y]
		elseif (y in setdiff(NEW_CAP_CHARGE, RET_CAP_CHARGE))
			dfGen[!,:Existing_Charge_Cap_MW][y] + EP[:vCAPCHARGE][y]
		elseif (y in setdiff(RET_CAP_CHARGE, NEW_CAP_CHARGE))
			dfGen[!,:Existing_Charge_Cap_MW][y] - EP[:vRETCAPCHARGE][y]
		else
			dfGen[!,:Existing_Charge_Cap_MW][y] + EP[:vZERO]
		end
	)

	## Objective Function Expressions ##

	# Fixed costs for resource "y" = annuitized investment cost plus fixed O&M costs
	# If resource is not eligible for new charge capacity, fixed costs are only O&M costs
	@expression(EP, eCFixCharge[y in STOR_ASYMMETRIC],
		if y in NEW_CAP_CHARGE # Resources eligible for new charge capacity
			dfGen[!,:Inv_Cost_Charge_per_MWyr][y]*vCAPCHARGE[y] + dfGen[!,:Fixed_OM_Cost_Charge_per_MWyr][y]*eTotalCapCharge[y]
		else
			dfGen[!,:Fixed_OM_Cost_Charge_per_MWyr][y]*eTotalCapCharge[y]
		end
	)

	# Sum individual resource contributions to fixed costs to get total fixed costs
	@expression(EP, eTotalCFixCharge, sum(EP[:eCFixCharge][y] for y in STOR_ASYMMETRIC))

	# Add term to objective function expression
	EP[:eObj] += eTotalCFixCharge

	### Constratints ###

	## Constraints on retirements and capacity additions
	#Cannot retire more charge capacity than existing charge capacity
 	@constraint(EP, cMaxRetCharge[y in RET_CAP_CHARGE], vRETCAPCHARGE[y] <= dfGen[!,:Existing_Charge_Cap_MW][y])

  	#Constraints on new built capacity

	# Constraint on maximum charge capacity (if applicable) [set input to -1 if no constraint on maximum charge capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is >= Max_Charge_Cap_MWh and lead to infeasabilty
    @constraint(EP, cMaxCapCharge[y in intersect(dfGen[dfGen.Max_Charge_Cap_MW.>0,:R_ID], STOR_ASYMMETRIC)], eTotalCapCharge[y] <= dfGen[y,:Max_Charge_Cap_MW])

	# Constraint on minimum charge capacity (if applicable) [set input to -1 if no constraint on minimum charge capacity]
	# DEV NOTE: This constraint may be violated in some cases where Existing_Charge_Cap_MW is <= Min_Charge_Cap_MWh and lead to infeasabilty
	@constraint(EP, cMinCapCharge[y in intersect(dfGen[dfGen.Min_Charge_Cap_MW.>0,:R_ID], STOR_ASYMMETRIC)], eTotalCapCharge[y] >= dfGen[y,:Min_Charge_Cap_MW])

	return EP
end
