function [G,S] = GetPhasorCoordinatesFromTable(data,cell_type,transfection,drug ,concentration)
%Function used to return phasor coordiantes
%For wells where no transfection or untreated but with compound/drug added
% this useful to determine if the drug effects the donor lifetime
% If the phasor coordinates are not found a general coordinates for untransfected cells is returned


    %%%%%%% USER DEFEIND PARAMETERS%%%%%
    G = 0.6079;
    S = 0.4645;


    [rows,~] = size(data);

    %if the transfection is DMSO (buffer only) then no need to check
    %concentration
    if strcmp(drug,'untreated')
    drug = 'DMSO'; 
    end
    if strcmp(drug,'DMSO')
        concentration = 'None';
    end

    %for untransfected cells there is no drug, no concentration
    if strcmp(concentration,'None')
        for i = 1:rows
            if( strcmp(char(data{i,1}),cell_type) && strcmp(char(data{i,2}),transfection) && strcmp(char(data{i,3}),drug))
                G = data(i,5) ;
                S = data(i,6); 
                return
            end
        end
    else
%        c_num = strsplit(concentration,'u'); 
        c_num = regexp(concentration,'u','split');
        current_concentration = str2num(c_num{1});
        concentration_array =[];
        concentration_indecies =[];
        concentration_count = 1; 
        for i = 1:rows
            if( strcmp(char(data{i,1}),cell_type) && strcmp(char(data{i,2}),transfection) && strcmp(char(data{i,3}),drug))
                c_str = char(data(i,4)); 
                c_num =   regexp(c_str,'u','split'); 
                concentration_array(concentration_count) = str2num(c_num{1}); 
                concentration_indecies(concentration_count) = i; 
                concentration_count = concentration_count + 1; 
            end
        end
  
    %Let's check if one of the concentrations matches the 
        %If concentration exist then use the phasor coordinate
        c_index = find(concentration_array == current_concentration);
        if(c_index)
            G = data(concentration_indecies(c_index),5);
            S = data(concentration_indecies(c_index),6);
            %we need to check that G and S is not NaN
            if isnan(G{1}) || isnan(S{1}) 
            c_index = find(concentration_array > current_concentration);
            if(c_index)
                sub_concentration_array = concentration_array(c_index); 
                [val,~] = min(sub_concentration_array); 
            
            
                c_index = find(concentration_array == val); 
            
            
                G = data(concentration_indecies(c_index),5);
                S = data(concentration_indecies(c_index),6);
                return
            else
                val = max(concentration_array); 
                c_index = find(concentration_array == val); 
                G = data(concentration_indecies(c_index),5);
                S = data(concentration_indecies(c_index),6);
                return 
            end
            end
       
            
        %If it does not exist then choose larger drug concentration
        elseif isnan(G) || isnan(S) 
            c_index = find(concentration_array > current_concentration);
            if(c_index)
                sub_concentration_array = concentration_array(c_index); 
                [val,~] = min(sub_concentration_array); 
            
            
                c_index = find(concentration_array == val); 
            
            
                G = data(concentration_indecies(c_index),5);
                S = data(concentration_indecies(c_index),6);
                return
            else
                val = max(concentration_array); 
                c_index = find(concentration_array == val); 
                G = data(concentration_indecies(c_index),5);
                S = data(concentration_indecies(c_index),6);
                return 
            end
        elseif isempty(c_index)
            display('[WARNING]: Could not find untransfected well for:');
            display(strcat(cell_type,'>>',drug,'(at any concentration)'));
            G = {G}; 
            S = {S}; 
            return 
        
        else 
             c_index = find(concentration_array > current_concentration);
            if(c_index)
                sub_concentration_array = concentration_array(c_index); 
                [val,~] = min(sub_concentration_array); 
            
            
                c_index = find(concentration_array == val); 
            
            
                G = data(concentration_indecies(c_index),5);
                S = data(concentration_indecies(c_index),6);
                return
            else
                val = max(concentration_array); 
                c_index = find(concentration_array == val); 
                G = data(concentration_indecies(c_index),5);
                S = data(concentration_indecies(c_index),6);
                return                
            end
        end
        
  end
      
    
   
end