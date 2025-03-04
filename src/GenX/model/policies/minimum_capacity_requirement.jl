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
	minimum_capacity_requirement(EP::Model, inputs::Dict)

The minimum capacity requirement constraint allows for modeling minimum deployment of a certain technology or set of eligible technologies across the eligible model zones and can be used to mimic policies supporting specific technology build out (i.e. capacity deployment targets/mandates for storage, offshore wind, solar etc.).
The default unit of the constraint is in MW. For each requirement $p \in \mathcal{P}^{MinCapReq}$, we model the policy with the following constraint.

```math
\begin{equation*}
	%\sum_{g \in \mathcal{G} } \sum_{z \in \mathcal{Z}} \left(\epsilon_{g,z,p}^{MinCapReq} \times y_{g,z}^{\textrm{E,GEN}} \right) \geq REQ_{p}^{MinCapReq} \forall p \in \mathcal{P}^{MinCapReq}
	\sum_{y \in \mathcal{G} } \sum_{z \in \mathcal{Z}} \left(\epsilon_{y,z,p}^{MinCapReq} \times x_{y,z}^{\textrm{E,GEN}} \right) \geq REQ_{p}^{MinCapReq} \forall p \in \mathcal{P}^{MinCapReq}
\end{equation*}
```

%Note that $\epsilon_{g,z,p}^{MinCapReq}$ is the eligiblity of a generator of technology $g$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources.
Note that $\epsilon_{y,z,p}^{MinCapReq}$ is the eligiblity of a generator of technology $y$ in zone $z$ of requirement $p$ and will be equal to $1$ for eligible generators and will be zero for ineligible resources.
The dual value of each minimum capacity constraint can be interpreted as the required payment (e.g. subsidy) per MW per year required to ensure adequate revenue for the qualifying resources.
"""
function minimum_capacity_requirement(EP::Model, inputs::Dict)

	print_and_log("Minimum Capacity Requirement Module")

	dfGen = inputs["dfGen"]
	NumberOfMinCapReqs = inputs["NumberOfMinCapReqs"]
	@constraint(EP, cZoneMinCapReq[mincap = 1:NumberOfMinCapReqs],
	sum(EP[:eTotalCap][y]
	for y in dfGen[(dfGen[!,Symbol("MinCapTag_$mincap")].== 1) ,:][!,:R_ID])
	>= inputs["MinCapReq"][mincap])

	return EP
end
