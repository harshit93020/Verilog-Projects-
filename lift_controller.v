`timescale 1ns/1ns

/**
 * LiftController module
 *
 * Inputs:
 *   - DirectionUp: single bit input from each floor. 1 means up request, 0 means no request for up direction
 *   - DirectionDown: single bit input from each floor. 1 means request for going down, 0 means no request for going down
 *   - Floors: [fl5, fl4, fl3, fl2, fl1, fl0] request for floor 5, 4, 3, 2, 1 respectively.
 *   - clk_M: input wire for the main clock
 *   - reset: input wire for the synchronous reset
 *
 * Outputs:
 *   - NextFloor: next stop of the lift
 *   - NextStopDirection: The lift will move in up/down direction in the next clock; 1 means up, 0 means down
 *   - clk: output reg for the clock
 *   - state: output reg [4:0] for the state
 *
 * Registers:
 *   - destination: 1. Destination (3 bits): If we are going to pick up a request, 
                    it refers to which floor we are going to. Otherwise, if we are fulfilling floor requests,
                    it stores the last floor in the current direction we have to go. 
 *   - dest_type: If we are going to pick up a request, it stores the type of request we are going to pick up (10: up, 01: down).
                  Otherwise, we are fulfilling floor requests, and it is set to 00 so we can choose requests carefully
                  and complete the request we are catering to as the first priority.
 *   - c_count: reg [25:0] for the clock count
 *
 * States:
 *   - 1,6,11,16,20: Idle states
 *   - 5,10,15: Moving states
     - Rest: Transistion states
 *
 * Synchronous Reset Behavior:
 *   - Resets the state to 1
 *   - Resets NextStopDirection to 2'b00
 *   - Resets NextFloor to 0
 *   - Resets dest_type to 2'b00
 *
 * @module LiftController
 */


module LiftController(
    input wire [4:0] DirectionUp,
    input wire [4:0] DirectionDown,
    input wire [4:0] Floors,
    output reg [2:0] NextFloor,
    output reg [1:0]NextStopDirection,
    output reg clk,
    input wire clk_M,
    output reg [4:0] state,
    input wire reset
    );
    
  // extra registers 
  reg [2:0] destination;
  reg [1:0] dest_type;

   //state register
  integer  i;
  reg [25:0] c_count;

  
  // The selected code initializes c_count and clk to 0,
  // and then toggles the value of clk every time c_count reaches 1, 
  // effectively generating a clock signal.
   initial begin
     c_count <= 0;
     clk <= 0;
   end
   
   
   always @(posedge clk_M) begin
     c_count = c_count + 1;
//     if(c_count == 64000000) begin
     if(c_count == 1) begin
         clk <= ~clk;
         c_count <=0;
     end
   end
   
    // main part involving transitions of states based on inputs
    always @(posedge clk) begin
    
      // synchronous reset  --> reaches to ground floor  irrespective of any inputs at present.
     
      if(reset == 1) begin
                state = 1 ;
                NextStopDirection = 2'b00;
                NextFloor = 0;
                dest_type = 2'b00;

      end
      else begin 
            case(state)
                1: begin  //0s will always be destination
                    // to handle faulty cases more specifically when we are at some floor there is some direction/floor request of that floor which is invalid. 
                    if(Floors[0] == 1 || DirectionUp[0] == 1 || DirectionDown[0] == 1) begin
                                   state = 1;
                    end
                    else begin
                            //if there is no request for any floor
                            if(Floors == 0) begin
                                //if there is no request from any floor we remain at that floor only.
                                if(DirectionUp == 0 && DirectionDown == 0)  begin              //idle state 
                                    NextFloor = 0;
                                    NextStopDirection = 2'b00 ;
                                    destination = 0;
                                    state = 1;
                                    dest_type = 2'b00;
                                end  
                                
                                else  begin
                                    //if there is request from any floor we will set dest_type(defination explained in report), next floor and next stop direction
                                    // and we take nearest floor as next floor and set destination(again, defination explained in report)  as well.
                                    for(i=4; i>=1; i = i-1) begin
                                        if(DirectionUp[i] == 1 || DirectionDown[i] == 1) begin
                                            destination = i;
                                            NextFloor = i;
                                            NextStopDirection = 2'b10;
                                            if(DirectionUp[i] == 1) 
                                                dest_type = 2'b10;
                                            else 
                                                dest_type = 2'b01;
                                        end
                                    end
                                    state = 2;
                                end
                            end

                            // if there is request for any floor
                            else begin
                                state = 2;
                                NextStopDirection = 2'b10; 
                                // the implementation for setting variables in almost all follwing states is based on the fact that we first set the destination and next floor based on direction opposite to optimal movement direction 
                                //  and then overwrite values of the same for checking in the optimal direction 
                                for(i=1; i<=4; i = i+1) begin
                                        if(Floors[i] == 1 ) begin
                                            destination = i;
                                            dest_type = 2'b00; 
                                        end
                                end

                                for(i=4; i>0; i = i-1) begin
                                        if(Floors[i] == 1) begin
                                            NextFloor = i;
                                        end
                                end

                                for(i = 3; i>=1; i=i-1) begin
                                        if(DirectionUp[i] == 1  )begin 
                                            NextFloor = i;
                                        end
                                end      
                            end
                    end
                end

                //Transistion state
                2: begin
                        if(NextStopDirection == 2'b10) begin
                        for(i = 3; i>=1; i=i-1) begin
                                    if(DirectionUp[i] == 1 && (destination == 4 || dest_type != 2'b01) ) begin 
                                        NextFloor = i;
                                    end
                            end   
                            state = 3;
                        end   
                        else begin 
                            state = 1;
                        end
                end
                //Transistion state
                3: begin
                        if(NextStopDirection == 2'b10) begin
                        for(i = 3; i>=1; i=i-1) begin
                                        if(DirectionUp[i] == 1  && (destination == 4 || dest_type != 2'b01) ) begin 
                                            NextFloor = i;
                                        
                                        end
                            end   
                            state = 4;
                        end   
                        else begin  
                            state = 2;
                        end           
                end
                //Transistion state
                4: begin
                        if(NextStopDirection == 2'b10) begin
                        for(i = 3; i>=1; i=i-1) begin
                                        if(DirectionUp[i] == 1  && (destination == 4 || dest_type != 2'b01) ) begin 
                                            NextFloor = i;
                                        
                                        end
                            end   

                            if(NextFloor == 1) state = 6;
                            else state = 5;
                        end   
                        else begin  
                            state = 3;
                        end                 
                end

                //Floor 1 moving
                5: begin
                        if(NextStopDirection == 2'b10) begin
                        for(i = 3; i>=1; i=i-1) begin
                                        if(DirectionUp[i] == 1  && (destination == 4 || dest_type != 2'b01) ) begin 
                                            NextFloor = i;
                                        
                                        end
                            end   
                            state = 7;
                        end   
                        else begin  
                            state = 4;
                        end    
                end

                //Floor 1 stopped
                6: begin
                    //Handle invalid cases when the lift is at floor 1
                    if(Floors[1] == 1 || DirectionUp[1] == 1 || DirectionDown[1] == 1) begin
                                    state = 6;
                    end
                    else begin
                        if(destination == 1 && dest_type != 2'b00) begin
                            NextStopDirection = dest_type;
                            dest_type = 2'b00;
                        end
                        if(destination == 1 && NextStopDirection == 2'b10) begin
                                    if(Floors == 0) begin
                                            if( (DirectionUp[1] ==1 || DirectionDown[1] == 1) || (DirectionDown == 0 && DirectionUp == 0)) begin
                                                    NextStopDirection = 2'b00;
                                                    NextFloor = 1;
                                                    dest_type = 2'b00;
                                            end
                                            else begin
                                                    if(DirectionUp[2] ==1 || DirectionDown[2] == 1) begin
                                                        destination = 2;
                                                        NextFloor = 2;
                                                        NextStopDirection = 2'b10;
                                                        state = 7;
                                                        if(DirectionUp[2] == 1) dest_type = 2'b10;
                                                        else dest_type = 2'b01;
                                                    end
                                                    else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                        destination = 0;
                                                        NextFloor = 0;
                                                        NextStopDirection = 2'b01;
                                                        state = 4;
                                                        if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                        else dest_type = 2'b01;
                                                    end
                                                    else if(DirectionUp[3] ==1 || DirectionDown[3] == 1) begin
                                                        destination = 3;
                                                        NextFloor = 3;
                                                        NextStopDirection = 2'b10;
                                                        state = 7;
                                                        if(DirectionUp[3] == 1) dest_type = 2'b10;
                                                        else dest_type = 2'b01;
                                                    end
                                                    else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                        destination = 4;
                                                        NextFloor = 4;
                                                        NextStopDirection = 2'b10;
                                                        state = 7;
                                                        if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                        else dest_type = 2'b01;
                                                    end
                                            end
                                    end
                                    else begin
                                        if(Floors[0] == 1) begin
                                            destination = 0; 
                                            dest_type = 2'b00; 
                                            NextFloor = 0;
                                            NextStopDirection = 2'b01;
                                        end
                                        for(i=2; i<5; i = i+1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                dest_type = 2'b00; 
                                                NextStopDirection = 2'b10;
                                            end
                                        end                        
                                        for(i=4; i>=2; i = i-1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            end
                                        end
                                        for(i = 3; i>=2; i=i-1) begin
                                            if(DirectionUp[i] == 1 && (dest_type != 2'b01 || destination == 4)) begin
                                                NextFloor = i; 
                                            end
                                        end
                                    end
                        end
                        else if(destination == 1 && NextStopDirection == 2'b01) begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 1;
                                                dest_type = 2'b00;
                                        end
                                        else begin
                                                if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    state = 4;
                                                    if(DirectionUp[0] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[2] ==1 || DirectionDown[2] == 1) begin
                                                    destination = 2;
                                                    NextFloor = 2;
                                                    NextStopDirection = 2'b10;
                                                    state = 7;
                                                    if(DirectionUp[2] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                            
                                                else if(DirectionUp[3] ==1 || DirectionDown[3] == 1) begin
                                                    destination = 3;
                                                    NextFloor = 3;
                                                    NextStopDirection = 2'b10;
                                                    state = 7;
                                                    if(DirectionUp[3] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    state = 7;
                                                    if(DirectionUp[4] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                        end
                                    end
                                    else begin
                                        for(i=2; i<5; i = i+1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                dest_type = 2'b00;
                                                NextStopDirection = 2'b10;
                                            end
                                        end                        
                                        for(i=4; i>=2; i = i-1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            
                                            end
                                        end
                
                                        for(i = 3; i>=2; i=i-1)  begin
                                            if(DirectionUp[i] == 1 && (destination == 4 || dest_type != 2'b01)) begin
                                                NextFloor = i; 
                                            end
                                        end

                                        if(Floors[0] == 1) begin
                                            destination = 0; 
                                            dest_type = 2'b00;
                                            NextFloor = 0;
                                            NextStopDirection = 2'b01;
                                        end
                                    end
                        end
                        else if(destination != 1 && NextStopDirection == 2'b10) begin
                            NextFloor = destination;
                            if(((destination == 4 || dest_type != 2'b01) && DirectionUp[2]  == 1) || (Floors[2] == 1)) NextFloor = 2;
                            else if((destination == 4 || dest_type != 2'b01) && DirectionUp[3] == 1 || (Floors[3] == 1)) NextFloor = 3;
                        end
                        else if(destination != 1 && NextStopDirection == 2'b01) begin
                            NextFloor = 0;
                        end
                        else begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 1;
                                                dest_type = 2'b00;
                                        end
                                        else begin
                                                if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    state = 4;
                                                    if(DirectionUp[0] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[2] ==1 || DirectionDown[2] == 1) begin
                                                    destination = 2;
                                                    NextFloor = 2;
                                                    NextStopDirection = 2'b10;
                                                    state = 7;
                                                    if(DirectionUp[2] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                            
                                                else if(DirectionUp[3] ==1 || DirectionDown[3] == 1) begin
                                                    destination = 3;
                                                    NextFloor = 3;
                                                    NextStopDirection = 2'b10;
                                                    state = 7;
                                                    if(DirectionUp[3] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    state = 7;
                                                    if(DirectionUp[4] == 1)  dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                        end
                                    end
                                    else begin
                                        for(i=2; i<5; i = i+1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                dest_type = 2'b00;
                                                NextStopDirection = 2'b10;
                                            end
                                        end                        
                                        for(i=4; i>=2; i = i-1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            
                                            end
                                        end
                
                                        for(i = 3; i>=2; i=i-1)  begin
                                            if(DirectionUp[i] == 1 && (destination == 4 || dest_type != 2'b01)) begin
                                                NextFloor = i; 
                                            end
                                        end

                                        if(Floors[0] == 1) begin
                                            destination = 0; 
                                            dest_type = 2'b00;
                                            NextFloor = 0;
                                            NextStopDirection = 2'b01;
                                        end
                                    end
                        end
                        if(NextStopDirection == 2'b00) state = 6;
                        else if(NextStopDirection == 2'b10) state = 7;
                        else state = 4; 
                    end
                    
                end

                //Transistion state
                7: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i>=2; i=i-1)  begin
                                    if(DirectionUp[i] == 1 && ( destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                    
                                    end
                            end   
                            state = 8;
                        end   
                        else begin 
                                for(i=0; i<=1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && ( destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                if(NextFloor == 1) state = 6;
                                else state = 5;
                            
                        end
                end
                
                //Transistion state
                8: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i>=2; i=i-1)  begin
                                    if(DirectionUp[i] == 1 && ( destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                
                                    end
                            end   
                            state = 9;
                        end   
                        else begin 
                                for(i=0; i<=1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && ( destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                state = 7;
                        end
                end

                //Transistion state
                9: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i>=2; i=i-1)  begin
                                    if(DirectionUp[i] == 1 && ( destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                    
                                    end
                            end   
                            if(NextFloor == 2) state = 11;
                            else state = 10;
                        end   
                        else begin 
                                for(i=0; i<=1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && ( destination == 0 || dest_type != 2'b10)) begin 
                                                NextFloor = i;
                                            
                                            end
                                end   
                                state = 8;
                        end
                end

                //Floor 2 moving
                10: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i>=3; i=i-1)  begin
                                    if(DirectionUp[i] == 1 && ( destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                    end
                            end   
                            state = 12;
                        end   
                        else begin 
                                for(i=0; i<=1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && ( destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                state = 9;
                        end
                end

                //Floor 2 stopped
                11: begin
                    if(Floors[2] == 1 || DirectionUp[2] == 1 || DirectionDown[2] == 1) begin
                        state = 11;
                    end
                    
                    else begin
                            if(destination == 2 && dest_type != 2'b00) begin
                                NextStopDirection = dest_type;
                                dest_type = 2'b00;
                            end

                            if(destination == 2 && NextStopDirection == 2'b10) begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 2;
                                                dest_type = 2'b00;
                                        end
                                        else begin
                                                if(DirectionUp[3] ==1 || DirectionDown[3] == 1) begin
                                                    destination = 3;
                                                    NextFloor = 3;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[3] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[1] ==1 || DirectionDown[1] == 1) begin
                                                    destination = 1;
                                                    NextFloor = 1;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[1] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end                            
                                                else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                        end
                                    end
                                    else begin
                                        for(i=1; i>=0; i = i-1) begin
                                            if(Floors[i] == 1 ) begin
                                                destination = i;
                                                NextStopDirection = 2'b01;
                                                dest_type = 00; 
                                            end
                                        end

                                        for(i=0; i<2; i = i+1) begin
                                            if(Floors[i] == 1 ) begin
                                                NextFloor = i;
                                            end
                                        end

                                        for(i=0; i<=1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10)) begin
                                                NextFloor = i; 
                                            
                                            end
                                        end


                                        for(i=3; i<5; i = i+1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                NextStopDirection = 2'b10;
                                                dest_type = 2'b00;                           
                                            end
                                        end                        
                                        for(i=4; i>=3; i = i-1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 

                                            end
                                        end
                                        for(i = 3; i>=3; i = i-1) begin
                                            if(DirectionUp[i] == 1 && (destination == 4 || dest_type != 2'b01)) begin
                                                NextFloor = i; 

                                            end
                                        end
                                    end
                            end
                            else if(destination == 2 && NextStopDirection == 2'b01) begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 2;
                                                dest_type = 2'b00; 
                                        end
                                        else begin
                                                if(DirectionUp[1] ==1 || DirectionDown[1] == 1) begin
                                                    destination = 1;
                                                    NextFloor = 1;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[1] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[3] ==1 || DirectionDown[3] == 1) begin
                                                    destination = 3;
                                                    NextFloor = 3;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[3] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end     
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end                            
                                        end
                                    end
                                    else begin
                                        
                                        for(i=3; i<5; i = i+1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                dest_type = 2'b00;
                                                NextStopDirection = 2'b10;

                                            end
                                        end                        
                                        for(i=4; i >= 3; i = i-1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            end
                                        end
                                        for(i = 3; i >= 3; i = i-1) begin
                                            if(DirectionUp[i] == 1 &&( destination == 4 || dest_type != 2'b01)) begin
                                                NextFloor = i; 
                                            end
                                        end

                                        for(i=1; i>=0; i = i-1) begin
                                            if(Floors[i] == 1 ) begin
                                                destination = i;
                                                NextStopDirection = 2'b01;
                                                dest_type = 2'b00;
                                            end
                                        end

                                        for(i=0; i<2; i = i+1) begin
                                            if(Floors[i] == 1 ) begin
                                                NextFloor = i;
                                            end
                                        end

                                        for(i=1; i <= 1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10) ) begin
                                                NextFloor = i; 
                                            end
                                        end
                                    end
                            end
                            else if(destination != 2 && NextStopDirection == 2'b10) begin
                                NextFloor = destination;
                                if(((destination == 4 || dest_type != 2'b01) && DirectionUp[3] == 1) || (Floors[3] == 1)) NextFloor = 3;
                            end
                            else if(destination != 2 && NextStopDirection == 2'b01) begin
                                    NextFloor = destination;
                                if(((destination == 0 || dest_type != 2'b10) && DirectionDown[1] == 1) || (Floors[1] == 1)) NextFloor = 1;
                            end
                            else begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 2;
                                                dest_type = 2'b00; 
                                        end
                                        else begin
                                                if(DirectionUp[1] ==1 || DirectionDown[1] == 1) begin
                                                    destination = 1;
                                                    NextFloor = 1;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[1] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[3] ==1 || DirectionDown[3] == 1) begin
                                                    destination = 3;
                                                    NextFloor = 3;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[3] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end     
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end                            
                                        end
                                    end
                                    else begin
                                        
                                        for(i=3; i<5; i = i+1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                dest_type = 2'b00;
                                                NextStopDirection = 2'b10;

                                            end
                                        end                        
                                        for(i=4; i >= 3; i = i-1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            end
                                        end
                                        for(i = 3; i >= 3; i = i-1) begin
                                            if(DirectionUp[i] == 1 &&( destination == 4 || dest_type != 2'b01)) begin
                                                NextFloor = i; 
                                            end
                                        end

                                        for(i=1; i>=0; i = i-1) begin
                                            if(Floors[i] == 1 ) begin
                                                destination = i;
                                                NextStopDirection = 2'b01;
                                                dest_type = 2'b00;
                                            end
                                        end

                                        for(i=0; i<2; i = i+1) begin
                                            if(Floors[i] == 1 ) begin
                                                NextFloor = i;
                                            end
                                        end

                                        for(i=1; i <= 1; i=i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10) ) begin
                                                NextFloor = i; 
                                            end
                                        end
                                    end
                            end

                            if(NextStopDirection == 2'b00) state = 11;
                            else if(NextStopDirection == 2'b10) state = 12;
                            else state = 9; 
                   end
                end

                //Transistion state
                12: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i >= 3; i=i-1) begin
                                    if(DirectionUp[i] == 1 && (destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                    end
                            end   
                            state = 13;
                        end   
                        else begin 
                                for(i=0; i>=2; i=i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                if(NextFloor == 2) state = 11;
                                else state = 10;
                            
                        end
                end
                    
                //Transistion state
                13: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i >= 3; i=i-1) begin
                                    if(DirectionUp[i] == 1 &&  (destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                    end
                            end   
                            state = 14;
                        end   
                        else begin 
                                for(i=0; i <= 2; i=i+1) begin
                                            if(DirectionDown[i] == 1 &&  (destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                state = 12;
                        end
                end

                //Transistion state
                14: begin
                        if(NextStopDirection == 2'b10) begin
                            for(i = 3; i >= 3; i=i-1) begin
                                    if(DirectionUp[i] == 1 &&  (destination == 4 || dest_type != 2'b01)) begin 
                                        NextFloor = i;
                                    end
                            end   
                            if(NextFloor == 3) state = 16;
                            else state = 15;
                        end   
                        else begin 
                                for(i=0; i <= 2; i=i+1) begin
                                            if(DirectionDown[i] == 1 &&  (destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                state = 13;
                        end
                end
            
                //Floor 3 moving
                15: begin
                        if(NextStopDirection == 2'b01) begin
                        for(i=1; i <=2; i=i+1) begin
                                        if(DirectionDown[i] == 1 &&  (destination == 0 || dest_type != 2'b10)) begin 
                                            NextFloor = i;
                                        end
                            end   
                            state = 14;
                        end   
                        else begin  
                            state = 17;
                        end    
                end

                //Floor 3 stopped
                16: begin
                    if(Floors[3] == 1 || DirectionUp[3] == 1 || DirectionDown[3] == 1) begin
                        state = 16;
                    end
                    else begin
                            if(destination == 3 &&  dest_type != 2'b00 ) begin
                                NextStopDirection = dest_type; 
                                dest_type = 2'b00; 
                            end

                            if(destination == 3 && NextStopDirection == 2'b01) begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 3;
                                                dest_type = 00; 
                                        end
                                        else begin
                                                if(DirectionUp[2] ==1 || DirectionDown[2] == 1) begin
                                                    destination = 2;
                                                    NextFloor = 2;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[2] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[1] ==1 || DirectionDown[1] == 1) begin
                                                    destination = 1;
                                                    NextFloor = 1;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[1] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                
                                                end
                                                else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                        end
                                    end
                                    else begin
                                        if(Floors[4] == 1) begin
                                            destination = 4; 
                                            NextFloor = 4;
                                            NextStopDirection = 2'b10;
                                            dest_type = 2'b00; 
                                        end
                                        for(i=2; i>=0; i = i-1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                NextStopDirection = 2'b01;
                                                dest_type = 2'b00; 

                                            end
                                        end                        
                                        for(i=0; i <= 2; i = i+1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            end
                                        end
                                        for(i = 1; i <= 2; i = i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10)) begin
                                                NextFloor = i; 
                                            end
                                        end
                                    end
                            end
                            else if(destination == 3 && NextStopDirection == 2'b10) begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 1;
                                                dest_type = 2'b00; 
                                        end
                                        else begin
                                                if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                                else if(DirectionUp[2] ==1 || DirectionDown[2] == 1) begin
                                                    destination = 2;
                                                    NextFloor = 2;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[2] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                

                                                end
                                            
                                                else if(DirectionUp[1] ==1 || DirectionDown[1] == 1) begin
                                                    destination = 1;
                                                    NextFloor = 1;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[1] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                
                                                end
                                                else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01;
                                                end
                                        end
                                    end
                                    else begin
                                        for(i=2; i>=0; i = i-1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                NextStopDirection = 2'b01;
                                                dest_type = 2'b00; 
                                            end
                                        end                        
                                        for(i=0; i>=2; i = i+1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            end
                                        end
                
                                        for(i=1; i <= 2; i = i+1) begin
                                            if(DirectionDown[i] == 1 &&( destination == 0 || dest_type != 2'b10)) begin
                                                NextFloor = i; 
                                            end
                                        end

                                        if(Floors[4] == 1) begin
                                            destination = 4; 
                                            NextFloor = 4;
                                            NextStopDirection = 2'b10;
                                            dest_type = 2'b00; 

                                        end
                                    end
                            end
                            else if(destination != 3 && NextStopDirection == 2'b01) begin
                                NextFloor = destination;
                                if(((destination == 0 || dest_type != 2'b10) && DirectionDown[2]  == 1) || (Floors[2] == 1)) NextFloor = 2;
                                else if((destination == 0 || dest_type != 2'b10) && DirectionDown[1] == 1 || (Floors[1] == 1)) NextFloor = 1;
                            end
                            else if(destination != 3 && NextStopDirection == 2'b10) begin
                                NextFloor = 4;
                            end
                            else begin
                                    if(Floors == 0) begin
                                        if(DirectionDown == 0 && DirectionUp == 0) begin
                                                NextStopDirection = 2'b00;
                                                NextFloor = 3;
                                                dest_type = 00; 
                                        end
                                        else begin
                                                if(DirectionUp[2] ==1 || DirectionDown[2] == 1) begin
                                                    destination = 2;
                                                    NextFloor = 2;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[2] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[4] ==1 || DirectionDown[4] == 1) begin
                                                    destination = 4;
                                                    NextFloor = 4;
                                                    NextStopDirection = 2'b10;
                                                    if(DirectionUp[4] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                                else if(DirectionUp[1] ==1 || DirectionDown[1] == 1) begin
                                                    destination = 1;
                                                    NextFloor = 1;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[1] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                
                                                end
                                                else if(DirectionUp[0] ==1 || DirectionDown[0] == 1) begin
                                                    destination = 0;
                                                    NextFloor = 0;
                                                    NextStopDirection = 2'b01;
                                                    if(DirectionUp[0] == 1) dest_type = 2'b10;
                                                    else dest_type = 2'b01; 
                                                end
                                        end
                                    end
                                    else begin
                                        if(Floors[4] == 1) begin
                                            destination = 4; 
                                            NextFloor = 4;
                                            NextStopDirection = 2'b10;
                                            dest_type = 2'b00; 
                                        end
                                        for(i=2; i>=0; i = i-1) begin
                                            if(Floors[i] == 1) begin
                                                destination = i;  
                                                NextStopDirection = 2'b01;
                                                dest_type = 2'b00; 

                                            end
                                        end                        
                                        for(i=0; i <= 2; i = i+1) begin 
                                            if(Floors[i] == 1)  begin
                                                NextFloor = i; 
                                            end
                                        end
                                        for(i = 0; i <= 2; i = i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10)) begin
                                                NextFloor = i; 
                                            end
                                        end
                                    end
                            end
                            
                            if(NextStopDirection == 2'b00) state = 16;
                            else if(NextStopDirection == 2'b10) state = 17;
                            else state = 14; 
                    end        
                end

                //Transistion state
                17: begin
                        if(NextStopDirection == 2'b10) begin
                            state = 18;
                        end   
                        else begin 
                                for(i=0; i <= 3; i=i+1) begin
                                            if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10)) begin 
                                                NextFloor = i;
                                            end
                                end   
                                if(NextFloor == 3) state = 16;
                                else state = 15;
                        end
                end      

                //Transistion state
                18: begin
                        if(NextStopDirection == 2'b10) begin
                            state = 19;
                        end   
                        else begin 
                                for(i=0; i <= 3; i=i+1) begin
                                            if(DirectionDown[i] == 1 &&( destination == 0 || dest_type != 2'b10) ) begin 
                                                NextFloor = i;
                                            end
                                end   
                                state = 17;
                        end
                end

                //Transistion state
                19: begin
                        if(NextStopDirection == 2'b01) begin
                            for(i=1; i <= 3; i=i+1) begin
                                    if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10)) begin 
                                        NextFloor = i;
                                    end
                            end   
                            state = 18;
                        end   
                        else begin 
                            state = 20;
                        end
                end

                //Floor 4 stopped
                20: begin  //4s will always be destination

                    if(Floors[4] == 1 || DirectionUp[4] == 1 || DirectionDown[4] == 1) begin
                        state = 20; 
                    end
                    else begin
                            if(Floors == 0) begin
                                if(DirectionUp == 0 && DirectionDown == 0)  begin              //idle state 
                                    NextFloor = 4;
                                    NextStopDirection = 2'b00 ;
                                    destination = 4;
                                    state = 20;
                                    dest_type = 2'b00;
                                end  
                                
                                else  begin 
                                    for(i=0; i <= 3; i = i+1) begin
                                        if(DirectionUp[i] == 1 || DirectionDown[i] == 1) begin
                                            destination = i;
                                            NextFloor = i;
                                            NextStopDirection = 2'b01;
                                            if(DirectionUp[i] == 1) dest_type = 2'b10;
                                            else dest_type = 2'b01;
                                        end
                                    end
                                    state = 19;
                                end
                            end

                            else begin
                                state = 19;
                                NextStopDirection = 2'b01; 
                                for(i=3; i >= 0; i = i-1) begin
                                        if(Floors[i] == 1 ) begin
                                            destination = i;
                                            dest_type = 2'b00; 
                                        end
                                end

                                for(i=0; i <= 3; i = i+1) begin
                                        if(Floors[i] == 1) begin
                                            NextFloor = i;
                                        end
                                end

                                for(i=1; i <= 3; i=i+1) begin
                                        if(DirectionDown[i] == 1 && (destination == 0 || dest_type != 2'b10)) begin 
                                            NextFloor = i;
                                        end
                                end      
                            end
                    end        
                end
            endcase
      end
  end 
endmodule