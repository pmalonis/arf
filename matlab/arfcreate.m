function arfcreate(filename, datasetname, size, varargin)
        p = inputParser;
        version = '2.2';
        spec_version = '2.1';
        datatype_codes = [0 1 2 3 4 5 6 23 1000 1001 1002 2000 2001 2002];
        
        % separate parameters passed to h5create and other parameters
        h5params = {};
        arfparams = {};
        h5_param_names = {'Datatype', 'ChunkSize', 'Deflate', 'FillValue', ...
            'Fletcher32', 'Shuffle'};

        for i = 1:2:length(varargin) - 1
            if any(strcmp(varargin{i},h5_param_names))
                h5params = [h5params varargin{i} varargin{i+1}];
            else
                arfparams = [arfparams varargin{i} varargin{i+1}];
            end
        end
        
        addParameter(p,'timestamp',0,@isnumeric)
        addParameter(p,'units','', @isstr)
        addParameter(p,'sampling_rate',0,@(x) (ceil(x)==x) & (x>0));
        addParameter(p,'arf_datatype',0,@(x) any(x==datatype_codes))
        parse(p,arfparams{:})

        %verify dataset attributes
        if strcmp(p.Results.units,'')
            if p.Results.sampling_rate == 0
                err = MException('arf:InvalidAttribute',...
                    ['Unitless data assumed time series and ' ... 
                    'requires sampling_rate attribute.']);
                throw(err)
            end
        elseif strcmp(p.Results.units,'samples')
            err = MExection('arf:InvalidAttribute',...
                ['Data with units of "samples" requires ' ... 
                'sampling_rate attribute.']);
            throw(err)
        end

        new_file = false; %indicates if h5create makes new file
        try
            info = h5info(filename);
        catch err
            if strcmp(err.identifier,'MATLAB:imagesci:h5info:libraryError')
                new_file = true;
            else
                rethrow(err) 
            end
        end
        new_file
        % obtaining list of new groups h5create will create
        new_groups = {}; 
        groups = strsplit(datasetname,'/');
        groups = {groups{1:end-1}};
        if ~new_file
            file_id = H5F.open(filename);
            for i = 1:length(groups)
                group_path = strjoin({groups{1:i}},'/');
                try
                    H5G.open(file_id, group_path);
                catch err
                    if strcmp(err.identifier,'MATLAB:imagesci:hdf5lib:libraryError')
                        new_groups = [new_groups, group_path];
                    else
                        rethrow(err)
                    end
                end
            end
            H5F.close(file_id)
        else
            for i = 1:length(groups)
                group_path = strjoin({groups{1:i}},'/');
                new_groups = [new_groups, group_path];                
            end
        end
        
        % create dataset
        h5create(filename,datasetname,size, h5params{:})
        
        % add attributes to root group if new file
        if new_file
            h5writeatt(filename,'/','arf_library', 'matlab');
            h5writeatt(filename,'/','arf_library_version',version);
            h5writeatt(filename,'/','arf_version',spec_version);
        end
        %add timestamp and uuid to group attributes
        for i = 1:length(new_groups)
            [~,uuid] = system('uuidgen');
            if p.Results.timestamp == 0
                [~,tstamp] = system('date +%s');
            else
                tstamp = p.Results.timestamp;
            end
            h5writeatt(filename,new_groups{i},'uuidgen',uuid)
            h5writeatt(filename,new_groups{i},'timestamp',tstamp)
        end
        
        %add attributes to dataset
        if ~strcmp(p.Results.units,'')
            h5writeatt(filename,datasetname,'units',p.Results.units)
        end
        if p.Results.sampling_rate > 0
            h5writeatt(filename,datasetname,'sampling_rate',...
                p.Results.sampling_rate)
        end 
        h5writeatt(filename,datasetname,'datatype',...
            uint16(p.Results.arf_datatype))
        
        
end