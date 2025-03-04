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
	co2_cap_hsc(EP::Model, inputs::Dict, setup::Dict)

This policy constraints mimics the CO$_2$ emissions cap and permit trading systems, allowing for emissions trading across each zone for which the cap applies. The constraint $p \in \mathcal{P}^{CO_2}$ can be flexibly defined for mass-based or rate-based emission limits for one or more model zones, where zones can trade CO$_2$ emissions permits and earn revenue based on their CO$_2$ allowance. Note that if the model is fully linear (e.g. no unit commitment or linearized unit commitment), the dual variable of the emissions constraints can be interpreted as the marginal CO$_2$ price per tonne associated with the emissions target. Alternatively, for integer model formulations, the marginal CO$_2$ price can be obtained after solving the model with fixed integer/binary variables.

The CO$_2$ emissions limit can be defined in one of the following ways: a) a mass-based limit defined in terms of annual CO$_2$ emissions budget (in million tonnes of CO2), b) a load-side rate-based limit defined in terms of tonnes CO$_2$ per MWh of demand and c) a generation-side rate-based limit defined in terms of tonnes CO$_2$ per MWh of generation.
	
**Mass-based emissions constraint**
	
Mass-based emission limits are implemented in the following expression. For each constraint, $p \in \mathcal{P}^{CO_2}_{mass}$, we define a set of zones $z \in \mathcal{Z}^{CO_2}_{p,mass}$ that can trade CO$_2$ allowance. Input data for each constraint  $p \in \mathcal{P}^{CO_2}_{mass}$ requires the CO$_2$ allowance/ budget for each model zone, $\epsilon^{CO_{2}}_{z,p, mass}$, to be provided in terms of million metric tonnes. For every generator $y$, the parameter $\epsilon_{y,z}^{CO_2}$ reflects the specific $CO_2$ emission intensity in tCO$_2$/MWh associated with its operation.  The resulting constraint is given as:
	
```math
\begin{aligned}
	\sum_{z \in \mathcal{Z}^{CO_2}_{p,mass}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} \left(\epsilon_{y,z}^{CO_2} \times \omega_t \times \Theta_{y,z,t} \right)
	& \leq \sum_{z \in \mathcal{Z}^{CO_2}_{p,mass}} \epsilon^{CO_{2}}_{z,p, mass} \hspace{1 cm}  \forall p \in \mathcal{P}^{CO_2}_{mass}
\end{aligned}
```
	
In the above constraint, we include both power discharge and charge term for each resource to account for the potential for CO$_2$ emissions (or removal when considering negative emissions technologies) associated with each step. Note that if a limit is applied to each zone separately, then the set $\mathcal{Z}^{CO_2}_{p,mass}$ will contain only one zone with no possibility of trading. If a system-wide emission limit constraint is applied, then $\mathcal{Z}^{CO_2}_{p,mass}$ will be equivalent to a set of all zones.
	
**Load-side rate-based emissions constraint**
	
We modify the right hand side of the above mass-based constraint, $p \in \mathcal{P}^{CO_2}_{load}$, to set emissions target based on a CO$_2$ emission rate limit in tCO$_2$/MWh $\times$ the total demand served in each zone. In the following constraint, total demand served takes into account non-served energy and storage related losses. Here, $\epsilon_{z,p,load}^{maxCO_2}$ denotes the emission limit in terms on tCO$_2$/MWh.
	
```math
\begin{aligned}
	\sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} \left(\epsilon_{y,z}^{CO_2} \times \omega_t \times \Theta_{y,t,z} \right)
	\leq & \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{t \in \mathcal{T}} \left(\epsilon_{z,p,load}^{CO_2} \times  \omega_t \times D_{z,t} \right) \\  + & \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{y \in \mathcal{O}}  \sum_{t \in \mathcal{T}} \left(\epsilon_{z,p,load}^{CO_2} \times \omega_t \times \left(\Pi_{y,t,z} - \Theta_{y,t,z} \right) \right) \\  - & \sum_{z \in \mathcal{Z}^{CO_2}_{p,load}} \sum_{s \in \mathcal{S} } \sum_{t \in \mathcal{T}}  \left(\epsilon_{z,p,load}^{CO_2} \times \omega_t \times \Lambda_{s,z,t}\right) \hspace{1 cm}  \forall p \in \mathcal{P}^{CO_2}_{load}
\end{aligned}
```
	
**Generator-side emissions rate-based constraint**
	
Similarly, a generation based emission constraint is defined by setting the emission limit based on the total generation times the carbon emission rate limit in tCO$_2$/MWh of the region. The resulting constraint is given as:
	
```math
\begin{aligned}
	\sum_{z \in \mathcal{Z}^{CO_2}_{p,gen}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} & \left(\epsilon_{y,z}^{CO_2} \times \omega_t \times \Theta_{y,t,z} \right) \\
	\leq \sum_{z \in \mathcal{Z}^{CO_2}_{p,gen}} \sum_{y \in \mathcal{G}} \sum_{t \in \mathcal{T}} & \left(\epsilon_{z,p,gen}^{CO_2} \times  \omega_t \times \Theta_{y,t,z} \right) \quad \forall p \in \mathcal{P}^{CO_2}_{gen}
\end{aligned}
```
	
Note that the generator-side rate-based constraint can be used to represent a fee-rebate (``feebate'') system: the dirty generators that emit above the bar ($\epsilon_{z,p,gen}^{maxCO_2}$) have to buy emission allowances from the emission regulator in the region $z$ where they are located; in the same vein, the clean generators get rebates from the emission regulator at an emission allowance price being the dual variable of the emissions rate constraint.	
"""
function co2_cap_hsc(EP::Model, inputs::Dict, setup::Dict)

	T = inputs["T"]     # Number of time steps (hours)
	H2_SEG= inputs["H2_SEG"] # Number of demand response segments for H2 demand

    # NOTE: If ParameterScale = 1 , then emisisons constraint written in units of ktonnes, else emissions constraint units is tonnes
    ## Mass-based: Emissions constraint in absolute emissions limit (tons)
    # eH2emissionsbyZones scaled in emissions_hsc.jl. RHS of constraint adjusted by modifying unit of CO2 intensity constraint
	if setup["H2CO2Cap"] == 1
		@constraint(EP, cH2CO2Emissions_systemwide[cap=1:inputs["H2NCO2Cap"]],
			sum(inputs["omega"][t] * EP[:eH2EmissionsByZone][z,t] for z=findall(x->x==1, inputs["dfH2CO2CapZones"][:,cap]), t=1:T) <=
			sum(inputs["dfH2MaxCO2"][z,cap] for z=findall(x->x==1, inputs["dfH2CO2CapZones"][:,cap]))
		)

	## Load + Rate-based: Emissions constraint in terms of rate (tons/tonnes)
    ## DEV NOTE: Add demand from H2 consumption by power sector after adding gas to power module
	elseif setup["H2CO2Cap"] == 2 
		@constraint(EP, cH2CO2Emissions_systemwide[cap=1:inputs["H2NCO2Cap"]],
			sum(inputs["omega"][t] * EP[:eH2EmissionsByZone][z,t] for z=findall(x->x==1, inputs["dfH2CO2CapZones"][:,cap]), t=1:T) <=
			sum(inputs["dfH2MaxCO2Rate"][z,cap] * sum(inputs["omega"][t] * 
			(inputs["H2_D"][t,z] + EP[:eH2DemandByZoneG2P][z,t] -
			 sum(EP[:vH2NSE][s,t,z] for s in 1:H2_SEG)) for t=1:T) for z = findall(x->x==1, inputs["dfH2CO2CapZones"][:,cap]))
		)

	## Generation + Rate-based: Emissions constraint in terms of rate (tonne CO2/tonne H2)
	elseif (setup["H2CO2Cap"]==3)
		@constraint(EP, cH2CO2Emissions_systemwide[cap=1:inputs["H2NCO2Cap"]],
			sum(inputs["omega"][t] * EP[:eH2EmissionsByZone][z,t] for z=findall(x->x==1, inputs["dfH2CO2CapZones"][:,cap]), t=1:T) <=
			sum(inputs["dfH2MaxCO2Rate"][z,cap] * inputs["omega"][t] * EP[:eH2GenerationByZone][z,t] for t=1:T, z=findall(x->x==1, inputs["dfH2CO2CapZones"][:,cap]))
		)
	end 

    
    return EP
end
