extensions [nw] ;; NW-Extension (NetLogo Network Extension)
                ;; I use this extension to cluster my network using k-means-clusters
                ;; website: https://github.com/NetLogo/NW-Extension#clusterers
globals [
  num-valves        ;;
  colors            ;;  
  source-colors     ;;
  init-colors       ;; 
  tmp-colors        ;;
  mains-min-size    ;;
  nb-clusters       ;; 
  ;num-of-changes    ;;
  ]

;;;The nodes represent junctions, tanks, and reservoirs. 

breed [junctions junction] ;; water consumers (nodes)
junctions-own [
  node_id 
  elevation 
  junction_demand 
  junction_pattern 
  junction_xcor 
  junction_ycor
  ]


breed [reservoirs reservoir]
reservoirs-own [
  node_id 
  elevation 
  reservoir_head 
  reservoir_xcor 
  reservoir_ycor
  ]


breed [tanks tank]
tanks-own [
  node_id 
  elevation 
  tank_initLevel 
  tank_minLevel 
  tank_maxLevel 
  tank_diameter 
  tank_minVol 
  tank_xcor 
  tank_ycor
  ]


;;;The links represent pipes, pumps, and control valves

undirected-link-breed [pipes pipe]
pipes-own [
  pipe_id 
  pipe_node1 
  pipe_node2 
  pipe_length 
  pipe_diameter 
  pipe_roughness 
  pipe_minorLoss 
  pipe_status weight
  ]


directed-link-breed [pumps pump]
pumps-own [
  pump_id 
  pump_parameters 
  weight
  ]


undirected-link-breed [valves valve]
valves-own []

;; 

to setup
  clear-all
  set mains-min-size 18
    
  ask patches [set pcolor white]
  set-default-shape junctions "circle"
  set-default-shape reservoirs "reservoir" 
  set-default-shape tanks "tank"
  set-default-shape pumps "pump"
  ask tanks [set color blue set size 1]
  ask reservoirs [set color blue set size 1]
  ask junctions [set color black set size 1]   
  set init-colors [brown green blue yellow pink orange lime cyan sky violet magenta turquoise gray]; etc.
  set colors init-colors
  set source-colors []
  
  reset-ticks
end


to cluster
  ;;
  ;; Garph clustering based on geographic information using k-means clustering algorithm
  ;;
  nw:set-snapshot turtles links
  
  ifelse (clusters-equals-sources) [
    set nb-clusters length source-colors
  ][
    set nb-clusters num-clusters
  ]
  
  let clusters nw:k-means-clusters nb-clusters 500 0.01

  ;; I need to find a way to start clustering from the source nodes
  ;; which nodes? - preferably reservoirs; if not enought reservoirs, larger tanks
  ifelse (nb-clusters < length source-colors)[
    set tmp-colors n-of nb-clusters sort source-colors
  ][
    set tmp-colors n-of nb-clusters sort init-colors
  ]
  (foreach clusters sort tmp-colors [
    let c ?2
    foreach ?1 [ ask ? [ set color c ] ]
  ])
  
  ask links  with [[color] of end1 != [color] of end2][
    set color red
  ]
  foreach tmp-colors [
    ask links with [[color] of end1 = ? and [color] of end2 = ?] [
      set color ?
    ]
  ]
  set num-valves count links with [color = red]
end


to negotiate-clusters
  ;;
  ;; Negotiating the clusters based on the closeness of the boundary nodes elevation to the neighbor clusters
  ;;

  let num-of-changes []
  ask links with [color = red] [
    ask one-of both-ends [
      set num-of-changes fput keep-or-change-cluster num-of-changes 
      ]
    ;show num-of-changes
  ]
  let total-num-of-changes 0
  if not empty? num-of-changes [
    set total-num-of-changes reduce + num-of-changes
  ]
    
  type "total number of changes is " type total-num-of-changes print ""
  
  while [total-num-of-changes >= threshold-num-of-changes] [
    set num-of-changes []
    ask links with [color = red] [
      ask one-of both-ends [
        set num-of-changes fput keep-or-change-cluster num-of-changes 
        ]
      ;show num-of-changes
      set total-num-of-changes reduce + num-of-changes
      ;show total-num-of-changes
      ;show num-of-changes
      
      ask links with [[color] of end1 != [color] of end2] [
        set color red
      ]
    ]
  ]
  
  ask links with [[color] of end1 != [color] of end2] [
    set color red
  ]
  
  foreach tmp-colors [
    ask links with [[color] of end1 = ? and [color] of end2 = ?] [
      set color ?
    ]
  ]
  
  set num-valves count links with [color = red]
    
;;;;;;; setting the mean of cluster elevation as a label for the longest link
;;;;;;; I have some problem with this so I've commented this piece of code
;  (foreach clusters [
;     let the-color [color] of one-of ?
;     let cluster-internal-links links with [([color] of end1 = the-color and [color] of end2 = the-color)]
;     ask one-of cluster-internal-links with [link-length = max [link-length] of cluster-internal-links] [
;       set label (mean [elevation] of turtles with [color = the-color])
;     ]
;  ])
  
end


to-report keep-or-change-cluster
  let change-flag 0
  let my-color color
  if (any? link-neighbors with [color != [color] of myself]) [
    let neighbor-color [color] of one-of (link-neighbors with [color != [color] of myself]) 
  
    let mean-elevation-my mean [elevation] of turtles with [color = my-color]
    let mean-elevation-neighbor mean [elevation] of turtles with [color = neighbor-color]
    if (elevation - mean-elevation-my > elevation - mean-elevation-neighbor) [
      set color neighbor-color
      set change-flag 1
      ;show "change cluster!!"
    ]
  ]
  report change-flag
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;; reading the files and importing the network data inot NetLoho ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to import-network
  import-nodes
  import-links
end

;; Reading files containing input nodes, reservoirs, tanks, links, pumps, etc.
to import-nodes
  ;; Opening the file
  file-open "Net3_junctions_with_coords.dat"
  ;; Read all of the file data are ordered
  while [not file-at-end?]
  [
    ;; reads a single line containing a list of several items
    ;; junctions-own [junction_id junction_elevation junction_demand junction_pattern junction_xcor junction_ycor]
    let items read-from-string ( word "[" file-read-line "]" )
    create-junctions 1 [
      set shape "circle"
      set color black
      set heading 0
      set node_id item 0 items
      set elevation item 1 items
      set junction_demand item 2 items
      set junction_pattern item 3 items
      set junction_xcor item 4 items
      set junction_ycor item 5 items
      set xcor junction_xcor
      set ycor junction_ycor
      ;set label item 0 items ; shows the node_id of each node
      ;; set sector item 6 items
      set label who ; shows the elevation of each node
      ]    
  ]
  file-close
  
  file-open "Net3_reservoirs_with_coords.dat"
  ;; Read all of the file data are ordered
  ;; reservoirs-own [reservoir_id, reservoir_head, reservoir_xcor, reservoir_ycor]
  while [not file-at-end?]
  [
    ;; reads a single line containing a list of several items
    let items read-from-string (word "[" file-read-line "]")
    create-reservoirs 1 [
      set shape "reservoir"
      set heading 0
      let the-color first colors
      set color the-color
      set colors but-first colors
      set source-colors lput the-color source-colors
      
      set node_id item 0 items
      set elevation item 1 items
      set reservoir_head item 2 items
      set reservoir_xcor item 3 items
      set reservoir_ycor item 4 items
      set xcor reservoir_xcor
      set ycor reservoir_ycor
      set label item 0 items ; shows the node_id of each node
      ]        
  ]
  file-close
  
  file-open "Net3_tanks_with_coords.dat"
  ;; Read all of the file data are ordered
  ;; tanks-own [tank_id tank_elevation tank_initLevel tank_minLevel tank_maxLevel tank_diameter tank_minVol tank_xcor tank_ycor]
  while [not file-at-end?]
  [
    ;; reads a single line containing a list of several items
    let items read-from-string (word "[" file-read-line "]")
    create-tanks 1 [
      set shape "tank"
      set heading 0
      let the-color first colors
      set color the-color
      set colors but-first colors
      set source-colors lput the-color source-colors

      set node_id item 0 items
      set elevation item 1 items
      set tank_initLevel item 2 items
      set tank_minLevel item 3 items
      set tank_maxLevel item 4 items
      set tank_diameter item 5 items
      set tank_minVol item 6 items
      set tank_xcor item 7 items
      set tank_ycor item 8 items
      set xcor tank_xcor
      set ycor tank_ycor
      set label item 0 items ; shows the node_id of each node
      ]        
  ]
  file-close

end

;; This procedure reads from another file that contains all the links

to import-links
  file-open "Net3_links.dat" 
  ;; pipes-own [pipe_id  pipe_node1 pipe_node2 pipe_length pipe_diameter pipe_roughness pipe_minorLoss pipe_status]
  while [not file-at-end?]
  [
    let items read-from-string (word "[" file-read-line "]")
    ask get-node (item 1 items)
    [
      create-pipe-with get-node (item 2 items) ;; 'with' make an undirected link
       [ set color black
         set pipe_id item 0 items
         set pipe_length item 3 items
         set pipe_diameter item 4 items
         ;set label item 4 items; shows the diameter of the pipe
         set pipe_roughness item 5 items
         set pipe_minorLoss item 6 items
         set pipe_status item 7 items
         ;set weight ((item 5 items) + (item 6 items)) / (item 4 items)
         ;set label item 6 items; shows the status of the pipe; 0 means open
        ]
     ]
   ]
  file-close
  
  file-open "Net3_pumps4NetLogo.dat" 
  while [not file-at-end?]
  [
    let items read-from-string (word "[" file-read-line "]")
    ask get-node (item 1 items)
    [
      create-pump-to get-node (item 2 items) 
       [ set color black
         set pump_id item 0 items
         set pump_parameters item 3 items
         set shape "pump"
         set label item 0 items; shows pump_id of the pipe
         ;set weight 0
        ]
     ]
   ]
  file-close
 
end

;;; find a node by its node-id, and reports is 'who' number
to-report get-node [id]
  report one-of turtles with [node_id = id]
end




































;
;to go   
;  build-clusters
;  ;update-plot
;  foreach source-colors [
;    if (count links with [color = ?] < 4) [  
;      build-clusters 
;      ;update-plot 
;    ]
;  ]
;  
;  ;; pipes with valves closed (isolation of sectors) are shown in red 
;  ask links  with [[color] of end1 != [color] of end2 ][
;    set color red
;  ]
;  set num-valves count links with [color  = red]
;end
;
;to build-clusters
;  ifelse clusters-equals-sources [
;    foreach source-colors [
;      ask turtles with [color = ?] [
;        create-cluster ;add-to-cluster 
;      ]
;    ]  
;  ][;else
;    let tmp-source-colors source-colors
;    repeat num-clusters [
;      let the-color one-of tmp-source-colors
;      ask turtles with [(breed = reservoirs or breed = tanks ) and color = the-color] [
;        create-cluster ;add-to-cluster 
;      ]
;      set tmp-source-colors remove the-color tmp-source-colors 
;    ]
;  ]
;end
;
;to create-cluster
;  ask link-neighbors [
;    add-to-my-cluster
;    ]
;end  
;  
;to add-to-my-cluster
;  ifelse any? link-neighbors with [color != [color] of myself and shape = "circle"]
;  [ 
;    ask one-of link-neighbors with [color != [color] of myself and shape = "circle"]
;    [
;      let old-color color
;      set color [color] of myself
;      ;if zoning [splotch]
;      ask my-links [set color [color] of myself]
;      
;      let elevation-cluster mean [elevation] of junctions with [color = [color] of myself]
;      let demand-cluster sum [junction_demand] of junctions with [color = [color] of myself]
;      let mean-demand-cluster mean [junction_demand] of junctions with [color = [color] of myself]
;      let resist weight-elevation * ([elevation] of self - elevation-cluster) + weight-demand * ([junction_demand] of self - mean-demand-cluster) 
;
;      ;;;;;add-to-cluster;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;      if random negotiate < resist [
;        set color old-color
;        ask my-links [set color old-color]
;        ;if zoning [splotch] 
;        build-clusters 
;      ]
;    ] 
;  ]
;  [ 
;    stop 
;  ]
;end   
;
;to add-to-cluster
;  ifelse any? link-neighbors with [color != [color] of myself and shape = "circle"]
;  [ 
;    ask one-of link-neighbors with [color != [color] of myself and shape = "circle"]
;    [
;      let old-color color
;      set color [color] of myself
;      ;if zoning [splotch]
;      ask my-links [set color [color] of myself]
;      
;      let elevation-cluster mean [elevation] of junctions with [color = [color] of myself]
;      let demand-cluster sum [junction_demand] of junctions with [color = [color] of myself]
;      let mean-demand-cluster mean [junction_demand] of junctions with [color = [color] of myself]
;      let resist weight-elevation * ([elevation] of self - elevation-cluster) + weight-demand * ([junction_demand] of self - mean-demand-cluster) 
;
;      ;;;;;add-to-cluster;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;      if random negotiate < resist [
;        set color old-color
;        ask my-links [set color old-color]
;        ;if zoning [splotch] 
;        build-clusters 
;      ]
;    ] 
;  ]
;  [ 
;    stop 
;  ]
;end   


;
; 
;to update-plot
;set-current-plot "hydraulic zones"
;set-current-plot-pen "sec1"
;  plot mean[demand] of turtles with [color = brown]
;set-current-plot-pen "sec2"
;  plot mean[demand] of turtles with [color = yellow]
;if n-clust = 3 [
;set-current-plot-pen "sec3"
;  plot mean[demand] of turtles with [color = green]
;  ]
;end
;
;to splotch
;  ask patches in-radius 100 [ set pcolor [color] of myself - 2]
;end
;

;
;to sensitivity
;;ask turtles [ set size 20 ]
;ask links with [ color = red ] [
;ask both-ends [set color blue ]
;]
;ifelse any? turtles with [color = blue ] [
;ask one-of turtles with [color = blue ] [
;  let d1 ( [xcor] of self - x1 + [ycor] of self - y1 )
;  let d2 ( [xcor] of self - x2 + [ycor] of self - y2 )
;  let d3 ( [xcor] of self - x3 + [ycor] of self - y3 )
;  if (d1 <= d2) and (d1 <= d3) [set color brown]
;  if (d2 <= d1) and (d2 <= d3) [set color yellow]
;  if (d3 <= d1) and (d3 <= d2) [set color green]
;  go; add-to-cluster
;  ] ]
;  [ stop ]
;end




; *** NetLogo 4.0.4 Code for Hydraulic Zoning in Water Supply Networks ***
;
; (C) 2009/10 IMM - UPV.  This code may be freely copied, distributed,
; altegreen, or otherwise used by anyone for any legal purpose.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
; A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
; OWNERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
; *** End of NetLogo 4.0.4 Code for Hydraulic Zoning Copyright Notice ***
@#$#@#$#@
GRAPHICS-WINDOW
463
11
1117
546
-1
-1
14.0
1
10
1
1
1
0
0
0
1
0
45
0
35
0
0
0
ticks
30.0

BUTTON
109
24
215
57
NIL
import-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
46
24
101
57
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
307
25
439
58
NIL
negotiate-clusters
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
155
107
243
160
num-valves
num-valves
0
1
13

CHOOSER
46
106
138
151
num-clusters
num-clusters
2 3 4 5 6 7 8 9 10
1

SWITCH
46
67
210
100
clusters-equals-sources
clusters-equals-sources
1
1
-1000

BUTTON
226
24
295
58
NIL
cluster
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
218
67
374
100
threshold-num-of-changes
threshold-num-of-changes
0
10
4
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

reservoir
true
0
Rectangle -7500403 true true 45 120 255 255
Rectangle -7500403 true true 240 90 255 45
Rectangle -7500403 true true 45 60 60 120
Rectangle -7500403 true true 240 60 255 120

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

tank
true
0
Rectangle -7500403 true true 105 90 120 90
Rectangle -7500403 true true 60 30 240 150
Rectangle -7500403 true true 105 150 195 240

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

pump
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Circle -7500403 true true 150 210 90
Rectangle -7500403 true true 150 75 165 270

@#$#@#$#@
0
@#$#@#$#@
