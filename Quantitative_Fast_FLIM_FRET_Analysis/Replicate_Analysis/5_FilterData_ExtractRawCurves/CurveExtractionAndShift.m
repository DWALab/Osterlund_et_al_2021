function [phasor_acceptor_shift, ino_acceptor_shift] = CurveExtractionAndShift(filename,bleedthrough_polyfit,G_donor,S_donor,unbound_lifetime, mc3_gradient_slope,ven_gradient_slope,acceptor_shift,estimate_shift)
%%% Function used to filter the raw CSV files generated by the INO FHS analysis
%%% if the estimate_shift is passed as true, then the shift in free acceptor is estimated
%%% The estimatoin of free acceptor depends on the estimated bound donor fractions (1:1 binding assumed)
%%% The INO FHS uses maximum likelihood approach to estimate the bound fraction
%%% We utilize the phasor approach.
%%% To run this script swallaow_csv.mex64 must be placed in the same folder for effecient loading of the large CSV files

    %%%% USER DEFINED PARAMETERS%%%%%

    A=[0.9169 0.276]; %phasor coordinate of bound lifetime


    %%%% Phasor constants
    freq0 = 30.51757e6;
    harmonic = 1;
    freq = harmonic * freq0;        % virtual frequency for higher harmonics
    w = 2 * pi * freq ;
    %%%% Sensitized Emission Factor %%%%
    G_FACTOR =7.9257; 
    
       
    %%CSV Columns Indecis
    sep = ','; %CSV files are separated by commas
    quote = '"';
    photon_counts_col = 16;
    tcspc_start_col = 19;
    tcspc_end_col = 19 + 400;

    %Get lifetime decays for all ROIs
    col_offset = 43; %tcscpc decays start at coloumn 43
    bound_fraction_col = 11; 
    tau1_col = 12; % col index for estimated first lifetime
    tau2_col = 13; % col index for estimated second lifetime 
    chi_col = 14; % col index for chi squared of the fit
    area_col = 17; %col index for ROI area
    min_photon_counts = 5000; %minimum photon counts within ROI
    

    %Read CSV file using swallow_csv (C++ code compiled to process .CSV files)
    % n is the matrix containing numerical data
    % t is the matrix containing text data here is omitted by using ~
    [n , ~] = swallow_csv(filename, quote, sep);


    ino_bound_fraction = (100 - n(:,bound_fraction_col))/100; 
    chi = n(:,chi_col); 
    tau1 = n(:,tau1_col); 
    tau2 = n(:,tau2_col);
    %calculate average tau using two lifetimes
    avg_tau = (ino_bound_fraction .* tau2) + (1 - ino_bound_fraction) .* tau1 ;
    fret = ( 1 - avg_tau/unbound_lifetime) * 100; 
    
    %Get mc3 photon counts 
    mc3_photon_counts = n(:,photon_counts_col);
    mc3_T0  = sum(n(:,tcspc_start_col + 42:tcspc_start_col + 44),2); 
    ven_spec_intensity = double(n(:,1632));
    roi_area = n(:,area_col); 



    % Filter using mCerulean3 Photoncounts
    mc3_photon_counts = mc3_photon_counts ./ roi_area;  
    good_rois  = find(mc3_photon_counts > 6 & mc3_photon_counts < 500); 
    mc3_photon_counts = mc3_photon_counts(good_rois); 
    ven_spec_intensity = ven_spec_intensity(good_rois); 
    roi_area = roi_area(good_rois); 
    mc3_T0  = mc3_T0(good_rois); 
    ino_bound_fraction = ino_bound_fraction(good_rois); 
    fret = fret(good_rois); 
    fret(fret<0) = 0 ; 
    chi = chi(good_rois); 


    %Get Decays for these ROIs 
    roi_decays = n(good_rois,tcspc_start_col + col_offset: tcspc_end_col);


    [r,c] = size(roi_decays);
    [G_fret, S_fret] = CalculatePhasorGSForDecayMatrix(roi_decays);
    
    %Determine average lifetime using phasor coordinates
    phasor_avg_lifetime =  S_fret ./ (harmonic * w * G_fret);    
 	phasor_lifetime = phasor_avg_lifetime * 1e12;
    phasor_fret =  ( 1 - phasor_lifetime/unbound_lifetime)*100; 

    %Determine bound fraction
    bound_fraction = zeros(1,r); 
    B=[G_donor S_donor]; 
    %Calculate the bound fraction from the phasor plot
    for i = 1:r
        GS_point = [G_fret(1,i) S_fret(1,i)];
        bound_fraction(1,i) =  GetBoundFractionVectorSpace(GS_point,A,B);
    end


    
    %Normalize ven and mc3 intensities by area
    ven_spec_intensity = ven_spec_intensity ./ roi_area; 
    mc3_T0  = mc3_T0 ./ roi_area;

  


    %Correct For Bleedthrough
    %first we remove the bleed through from the donor channel in to the
    %acceptor channel
    bt_slope = bleedthrough_polyfit(1); 
    bt_intercept = bleedthrough_polyfit(2); 
    ven_spec_intensity = ven_spec_intensity - (bt_slope * mc3_photon_counts + bt_intercept); 
    ven_c = ven_spec_intensity * ven_gradient_slope;
    %we determine the [mC3] concentration per roi ; 
    mc3_concentration = (mc3_gradient_slope * mc3_T0);
    
    %Correct of Sensitized emission
    %the senesitized emission Fc can be calculated using the follow int
    %equation: Fc = G_factor * [mC3] * E_D / (E_D  + alpha); (E_D is the fret);
    % alpha was determined to be 0.127 for our experimental setup. 
    %Determine the increase in spectral intensity due to sensitized emission
    ven_sensetized_emission = (G_FACTOR*mc3_concentration.*fret)./(0.127+fret);
    ven_sensetized_emission(ven_sensetized_emission< 0) = 0;
    %We subtract the sensitized emission from the Venus channel. 
%     ven_concentration = ven_spec_intensity * ven_gradient_slope; 
%     ven_concentration(ven_concentration < 0 ) = 0;
%     ven_added =  ven_concentration - ven_sensetized_emission; 
    
    ven_added = ven_c - (ven_sensetized_emission * ven_gradient_slope); 

    %calculate acceptor to donor ratio
    
    ad_ratio = ven_spec_intensity ./ mc3_photon_counts; 
  
    %THIS IS WHERE mCerulean3 concentration filter is applied
    
    good_mc3_concentration = find(mc3_concentration > 0.5 & mc3_concentration < 8.0 );
    chi = chi(good_mc3_concentration); 
    
    bound_fraction = bound_fraction(good_mc3_concentration); 
    ino_bound_fraction = ino_bound_fraction(good_mc3_concentration); 
    
    mc3_concentration = mc3_concentration(good_mc3_concentration); 
    ven_added = ven_added(good_mc3_concentration) ;
    fret=fret(good_mc3_concentration); 
    phasor_fret = phasor_fret(good_mc3_concentration); 
    ad_ratio = ad_ratio(good_mc3_concentration);
    
    free_acceptor = ven_added - (mc3_concentration .* bound_fraction');
    ino_free_acceptor = ven_added - (mc3_concentration .* ino_bound_fraction);
    
    
    if(estimate_shift)
        phasor_acceptor_shift = prctile(free_acceptor,90); 
        ino_acceptor_shift = prctile(ino_free_acceptor, 90);
        return
    else
        phasor_acceptor_shift = 0 ; 
        ino_acceptor_shift = 0 ; 
    end
    
    
    
    
    free_acceptor = free_acceptor + acceptor_shift; 
    
    
    current_path = pwd; 
    path_to_analysis_folder = fullfile(current_path,'RawCurves');
    
    
    
    %Check if path to export folder exist
    if~(exist(path_to_analysis_folder,'dir'))
        mkdir(path_to_analysis_folder)
    end


    [filepath,name,ext] = fileparts(filename);
    output_filename = strcat(path_to_analysis_folder,'\',name,'_filtered_raw.csv'); 
    test_results=[ven_added, mc3_concentration,free_acceptor,bound_fraction',phasor_fret',ino_free_acceptor,ino_bound_fraction, ad_ratio, fret, chi]; 
    column_headers ={'Ven_concentration','mC3_concentration','free_Ven_concentration','bound_mC3_fraction', 'Phasor_FRET', ...
        'INO_free_Ven','INO_bound_fraction','acceptor_to_donor_ratio','INO_FRET','INO_chi'};
    
    try
        %csvwrite(output_filename,test_results);
        SaveToCSVWithColumnNames(output_filename,test_results,column_headers); 

    catch
        disp('[INFO] Could not save raw filtered file. Please check directory path')
        return
    end




end

