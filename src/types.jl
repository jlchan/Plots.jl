
typealias AVec AbstractVector
typealias AMat AbstractMatrix

immutable PlotsDisplay <: Display end
  
abstract PlottingPackage
abstract PlottingObject{T<:PlottingPackage}

type Plot{T<:PlottingPackage} <: PlottingObject{T}
  o  # the underlying object
  backend::T
  n::Int  # number of series

  # store these just in case
  initargs::Dict
  seriesargs::Vector{Dict} # args for each series
end


abstract SubplotLayout

immutable GridLayout <: SubplotLayout
  nr::Int
  nc::Int
end

immutable FlexLayout <: SubplotLayout
  numplts::Int
  rowcounts::AbstractVector{Int}
end


type Subplot{T<:PlottingPackage, L<:SubplotLayout} <: PlottingObject{T}
  o                           # the underlying object
  plts::Vector{Plot}          # the individual plots
  backend::T
  p::Int                      # number of plots
  n::Int                      # number of series
  layout::L
  initargs::Vector{Dict}
  initialized::Bool
  linkx::Bool
  linky::Bool
  linkfunc::Function # maps (row,column) -> (BoolOrNothing, BoolOrNothing)... if xlink/ylink are nothing, then use subplt.linkx/y
end

# -----------------------------------------------------------------------

immutable Shape
  vertices::AVec
end

"get an array of tuples of points on a circle with radius `r`"
function partialcircle(start_θ, end_θ, n = 20, r=1)
  @compat(Tuple{Float64,Float64})[(r*cos(u),r*sin(u)) for u in linspace(start_θ, end_θ, n)]
end

"interleave 2 vectors into each other (like a zipper's teeth)"
function weave(x,y; ordering = Vector[x,y])
  ret = eltype(x)[]
  done = false
  while !done
    for o in ordering
      try
          push!(ret, shift!(o))
      end
      # try
      #     push!(ret, shift!(y))
      # end
    end
    done = isempty(x) && isempty(y)
  end
  ret
end


"create a star by weaving together points from an outer and inner circle.  `n` is the number of arms"
function makestar(n; offset = -0.5, radius = 1.0)
    z1 = offset * π
    z2 = z1 + π / (n)
    outercircle = partialcircle(z1, z1 + 2π, n+1, radius)
    innercircle = partialcircle(z2, z2 + 2π, n+1, 0.4radius)
    Shape(weave(outercircle, innercircle)[1:end-2])
end

"create a shape by picking points around the unit circle.  `n` is the number of point/sides, `offset` is the starting angle"
function makeshape(n; offset = -0.5, radius = 1.0)
    z = offset * π
    Shape(partialcircle(z, z + 2π, n+1, radius)[1:end-1])
end


function makecross(; offset = -0.5, radius = 1.0)
    z2 = offset * π
    z1 = z2 - π/8
    outercircle = partialcircle(z1, z1 + 2π, 9, radius)
    innercircle = partialcircle(z2, z2 + 2π, 5, 0.5radius)
    Shape(weave(outercircle, innercircle, 
                ordering=Vector[outercircle,innercircle,outercircle])[1:end-2])
end


const _shapes = Dict(
    :ellipse => makeshape(20),
    :rect => makeshape(4, offset=-0.25),
    :diamond => makeshape(4),
    :utriangle => makeshape(3),
    :dtriangle => makeshape(3, offset=0.5),
    :pentagon => makeshape(5),
    :hexagon => makeshape(6),
    :heptagon => makeshape(7),
    :octagon => makeshape(8),
    :cross => makecross(offset=-0.25),
    :xcross => makecross(),
  )

for n in [4,5,6,7,8]
  _shapes[symbol("star$n")] = makestar(n)
end

# -----------------------------------------------------------------------

"Wrap a string with font info"
immutable PlotText
  str::@compat(AbstractString)
  family::Symbol
  pointsize::Int
  halign::Symbol
  valign::Symbol
  rotation::Float64
  color::Colorant
end


function text(str, args...)
  
  # defaults
  family = :courier
  pointsize = 12
  halign = :hcenter
  valign = :vcenter
  rotation = 0.0
  color = colorant"black"

  for arg in args
    if arg == :center
      halign = :hcenter
      valign = :vcenter
    elseif arg in (:hcenter, :left, :right)
      halign = arg
    elseif arg in (:vcenter, :top, :bottom)
      valign = arg
    elseif typeof(arg) <: Colorant
      color = arg
    elseif isa(arg, Symbol)
      try
        color = parse(Colorant, string(arg))
      catch
        family = arg
      end
    elseif typeof(arg) <: Integer
      pointsize = arg
    elseif typeof(arg) <: Real
      rotation = convert(Float64, arg)
    else
      warn("Unused font arg: $arg ($(typeof(arg)))")
    end
  end

  PlotText(string(str), family, pointsize, halign, valign, rotation, color)
end

# -----------------------------------------------------------------------

type OHLC{T<:Real}
  open::T
  high::T
  low::T
  close::T
end
