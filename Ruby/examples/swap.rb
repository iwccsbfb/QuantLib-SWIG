
# Copyright (C) 2004 StatPro Italia srl
#
# This file is part of QuantLib, a free-software/open-source library
# for financial quantitative analysts and developers - http://quantlib.org/
#
# QuantLib is free software: you can redistribute it and/or modify it under the
# terms of the QuantLib license.  You should have received a copy of the
# license along with this program; if not, please email quantlib-dev@lists.sf.net
# The license is also available online at http://quantlib.org/html/license.html
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the license for more details.

require 'QuantLib'
include QuantLib

# global data
calendar = Calendar.new('TARGET')
todaysDate = Date.new(6,11,2001);
settlementDate = Date.new(8,11,2001);

# market quotes
deposits = [ [1,'week',   SimpleQuote.new(0.0382)],
             [1,'month',  SimpleQuote.new(0.0372)],
             [3,'months', SimpleQuote.new(0.0363)],
             [6,'months', SimpleQuote.new(0.0353)],
             [9,'months', SimpleQuote.new(0.0348)],
             [1,'year',   SimpleQuote.new(0.0345)] ]

fras = { [3,6]  => SimpleQuote.new(0.037125),
         [6,9]  => SimpleQuote.new(0.037125),
         [9,12] => SimpleQuote.new(0.037125) }

futures = { Date.new(19,12,2001) => SimpleQuote.new(96.2875),
            Date.new(20,3,2002)  => SimpleQuote.new(96.7875),
            Date.new(19,6,2002)  => SimpleQuote.new(96.9875),
            Date.new(18,9,2002)  => SimpleQuote.new(96.6875),
            Date.new(18,12,2002) => SimpleQuote.new(96.4875),
            Date.new(19,3,2003)  => SimpleQuote.new(96.3875),
            Date.new(18,6,2003)  => SimpleQuote.new(96.2875),
            Date.new(17,9,2003)  => SimpleQuote.new(96.0875) }

swaps = { [2,'years']  => SimpleQuote.new(0.037125),
          [3,'years']  => SimpleQuote.new(0.0398),
          [5,'years']  => SimpleQuote.new(0.0443),
          [10,'years'] => SimpleQuote.new(0.05165),
          [15,'years'] => SimpleQuote.new(0.055175) }

# build rate helpers

dayCounter = DayCounter.new('act/360')
settlementDays = 2
depositHelpers = deposits.map { |n,unit,v|
  DepositRateHelper.new(QuoteHandle.new(v),
                        n, unit, settlementDays,
                        calendar, 'mf', dayCounter)
}

dayCounter = DayCounter.new('act/360')
settlementDays = 2
fraHelpers = fras.map { |(n,m),v|
  FraRateHelper.new(QuoteHandle.new(v),
                    n, m, settlementDays,
                    calendar, 'mf', dayCounter)
}

dayCounter = DayCounter.new('act/360')
months = 3
futuresHelpers = futures.map { |d,v|
  FuturesRateHelper.new(QuoteHandle.new(v),
                        d, months,
                        calendar, 'mf', dayCounter)
}

settlementDays = 2
fixedLegFrequency = 1
fixedLegAdjustment = false
fixedLegDayCounter = DayCounter.new('30/360')
floatingLegFrequency = 2
swapHelpers = swaps.map {|(n,unit),v|
  SwapRateHelper.new(QuoteHandle.new(v),
                     n, unit, settlementDays,
                     calendar, 'mf',
                     fixedLegFrequency, fixedLegAdjustment,
                     fixedLegDayCounter, floatingLegFrequency)
}

# term structure handles

discountTermStructure = TermStructureHandle.new
forecastTermStructure = TermStructureHandle.new

# term-structure construction

helpers = depositHelpers[0..1] + futuresHelpers + swapHelpers[1..-1]
depoFuturesSwapCurve = PiecewiseFlatForward.new(todaysDate, settlementDate,
                                                helpers, 
                                                DayCounter.new('act/360'))

helpers = depositHelpers[0..2] + fraHelpers + swapHelpers
depoFraSwapCurve = PiecewiseFlatForward.new(todaysDate, settlementDate,
                                            helpers, DayCounter.new('act/360'))

# swaps to be priced

nominal = 1000000
length = 5
payFixed = true

fixedLegFrequency = 1
fixedLegAdjustment = false
fixedLegDayCounter = DayCounter.new('30/360')
fixedRate = 0.04

floatingLegFrequency = 2
spread = 0.0
fixingDays = 2
index = Xibor.new('Euribor', 6, 'months', forecastTermStructure)

spot = SimpleSwap.new(payFixed, settlementDate, length, 'years',
                      calendar, 'mf', nominal, fixedLegFrequency,
                      fixedRate, fixedLegAdjustment, fixedLegDayCounter,
                      floatingLegFrequency, index, fixingDays, spread,
                      discountTermStructure)

forward = SimpleSwap.new(payFixed, calendar.advance(settlementDate,1,'year'),
                         length, 'years', calendar, 'mf', nominal,
                         fixedLegFrequency, fixedRate, fixedLegAdjustment,
                         fixedLegDayCounter, floatingLegFrequency, index,
                         fixingDays, spread, discountTermStructure)

# price on the bootstrapped curves

def formatPrice(p,digits=2)
  format = "%.#{digits}f"
  return sprintf(format, p)
end

def formatRate(r,digits=2)
  format = "%.#{digits}f %%"
  return sprintf(format,r*100)
end

Format = '%17s |%17s |%17s |%17s'
header = sprintf(Format,"term structure", "net present value",
                 "fair spread", "fair fixed rate")
width = header.length

rule = "-" * width
dblrule = "=" * width
tab = " " * 8

def report(swap, name)
  puts sprintf(Format, name, formatPrice(swap.NPV,2),
               formatRate(swap.fairSpread,4),
               formatRate(swap.fairRate,4))
end

puts dblrule

puts "5-year market swap-rate = #{formatRate(swaps[[5,'years']].value)}"
puts dblrule

# price on two different term structures

puts "#{tab}5-years swap paying #{formatRate(fixedRate)}"
puts header
puts rule

discountTermStructure.linkTo!(depoFuturesSwapCurve)
forecastTermStructure.linkTo!(depoFuturesSwapCurve)
report(spot,'depo-fut-swap')

discountTermStructure.linkTo!(depoFraSwapCurve)
forecastTermStructure.linkTo!(depoFraSwapCurve)
report(spot,'depo-FRA-swap')

puts rule

# price the 1-year forward swap

puts "#{tab}5-years, 1-year forward swap paying #{formatRate(fixedRate)}"
puts rule

discountTermStructure.linkTo!(depoFuturesSwapCurve)
forecastTermStructure.linkTo!(depoFuturesSwapCurve)
report(forward,'depo-fut-swap')

discountTermStructure.linkTo!(depoFraSwapCurve)
forecastTermStructure.linkTo!(depoFraSwapCurve)
report(forward,'depo-FRA-swap')

# modify the 5-years swap rate and reprice

swaps[[5,'years']].value = 0.046

puts dblrule
puts "5-year market swap-rate = #{formatRate(swaps[[5,'years']].value)}"
puts dblrule

puts "#{tab}5-years swap paying #{formatRate(fixedRate)}"
puts header
puts rule

discountTermStructure.linkTo!(depoFuturesSwapCurve)
forecastTermStructure.linkTo!(depoFuturesSwapCurve)
report(spot,'depo-fut-swap')

discountTermStructure.linkTo!(depoFraSwapCurve)
forecastTermStructure.linkTo!(depoFraSwapCurve)
report(spot,'depo-FRA-swap')

puts rule

puts "#{tab}5-years, 1-year forward swap paying #{formatRate(fixedRate)}"
puts rule

discountTermStructure.linkTo!(depoFuturesSwapCurve)
forecastTermStructure.linkTo!(depoFuturesSwapCurve)
report(forward,'depo-fut-swap')

discountTermStructure.linkTo!(depoFraSwapCurve)
forecastTermStructure.linkTo!(depoFraSwapCurve)
report(forward,'depo-FRA-swap')