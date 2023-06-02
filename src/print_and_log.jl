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
    print_and_log(message::AbstractString)

This function takes a message which is one-piece string in julia and print it in console or 
log file depending on global ```Log``` flag.
"""
function print_and_log(message::AbstractString)

    if Log && message isa AbstractString
        println(message)
        @info(message)

    elseif Log && message isa Number
        println(string(message, base=10, pad=10))
        @info(string(message, base=10, pad=10))

    else
        println(message)
    
    end

end
