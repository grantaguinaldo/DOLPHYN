# Small New England: Three Zones

**SmallNewEngland** is set of a simplified power and hydrogen models. It is condensed for easy comprehension and quick testing of different components of the DOLPHYN. **SmallNewEngland/ThreeZones**, a one-year example with hourly resolution, contains zones representing Massachusetts, Connecticut, and Maine. The ten represented power resources include only natural gas, solar PV, wind, and lithium-ion battery storage. The hydrogen resources include electrolyzers, SMRs, SMRs with CCS, and above ground storage in each zone. Pipelines allow for hydrogen transport between zones.

To run the model, first navigate to the example directory at `DOLPHYN-dev/Example_Systems/SmallNewEngland/ThreeZones`:

`cd("Example_Systems/SmallNewEngland/ThreeZones")`
   
Next, ensure that your settings in `GenX_settings.yml` are correct. The default settings use the solver Gurobi (`Solver: Gurobi`), time domain reduced input data (`TimeDomainReduction: 1`). Other optional policies include minimum capacity requirements, a capacity reserve margin, and more. A rate-based carbon cap of 50 gCO<sub>2</sub> per kWh is specified in the `CO2_cap.csv` input file.

Once the settings are confirmed, run the model with the `Run.jl` script in the example directory:

`include("Run.jl")`

Once the model has completed, results will write to the `Results` directory. You can compare these results to example results (using the default settings provided here) in `Results_Example`, by running:

`include("Check_results.jl")`

If the example has run successfully, all of the files except `status.csv` should be identical