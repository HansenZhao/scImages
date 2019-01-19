function hsAbleHandle( h,comd )
    if isprop(h,'Children')
        childList = h.Children;
        if ~isempty(childList)
            L = length(childList);
            for m = 1:L
                hsAbleHandle(childList(m),comd);
            end
        end
    end
    if isprop(h,'Enable')
        h.Enable = comd;
    end
end

