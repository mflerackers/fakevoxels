class = function(...)
  local klass = {}
  klass.__index = klass
  klass.__call = function(_,...) return klass:new(...) end
  function klass:new(...)
    local instance = setmetatable({}, klass)
    klass.__init(instance, ...)
    return instance
  end
  return setmetatable(klass,{__call = klass.__call})
end
