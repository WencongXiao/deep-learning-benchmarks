--
--  Copyright (c) 2016, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.
--
--  Generic model creating code. For the specific ResNet model see
--  models/resnet.lua
--

require 'nn'

local M = {}

function M.setup(opt, checkpoint)
   if opt.deviceId >= 0 then
       require 'cudnn'
       require 'cunn'
   end

   local model
   if checkpoint then
      local modelPath = paths.concat(opt.resume, checkpoint.modelFile)
      assert(paths.filep(modelPath), 'Saved model not found: ' .. modelPath)
      print('=> Resuming model from ' .. modelPath)
      model = torch.load(modelPath)
   elseif opt.retrain ~= 'none' then
      assert(paths.filep(opt.retrain), 'File not found: ' .. opt.retrain)
      print('Loading model from file: ' .. opt.retrain)
      model = torch.load(opt.retrain)
   else
      print('=> Creating model from file: models/' .. opt.netType .. '.lua')
      model = require('models/' .. opt.netType)(opt)
   end

   -- First remove any DataParallelTable
   if torch.type(model) == 'nn.DataParallelTable' then
      model = model:get(1)
   end

   -- This is useful for fitting ResNet-50 on 4 GPUs, but requires that all
   -- containers override backwards to call backwards recursively on submodules
   if opt.shareGradInput then
      local function sharingKey(m)
         local key = torch.type(m)
         if m.__shareGradInputKey then
            key = key .. ':' .. m.__shareGradInputKey
         end
         return key
      end

      -- Share gradInput for memory efficient backprop
      local cache = {}
      model:apply(function(m)
         local moduleType = torch.type(m)
         if torch.isTensor(m.gradInput) and moduleType ~= 'nn.ConcatTable' then
            local key = sharingKey(m)
            if cache[key] == nil then
               if opt.deviceId >= 0 then
                   cache[key] = torch.CudaStorage(1)
               else
                   cache[key] = torch.FloatStorage(1)
               end
            end
            if opt.deviceId >= 0 then
                m.gradInput = torch.CudaTensor(cache[key], 1, 0)
            else
                m.gradInput = torch.FloatTensor(cache[key], 1, 0)
            end
         end
      end)
      for i, m in ipairs(model:findModules('nn.ConcatTable')) do
         if cache[i % 2] == nil then
             if opt.deviceId >= 0 then
                 cache[i % 2] = torch.CudaStorage(1)
             else
                 cache[i % 2] = torch.FloatStorage(1)
             end

         end
         if opt.deviceId >= 0 then
             m.gradInput = torch.CudaTensor(cache[i % 2], 1, 0)
         else
             m.gradInput = torch.FloatTensor(cache[i % 2], 1, 0)
         end
      end
   end

   -- For resetting the classifier when fine-tuning on a different Dataset
   if opt.resetClassifier and not checkpoint then
      print(' => Replacing classifier with ' .. opt.nClasses .. '-way classifier')

      local orig = model:get(#model.modules)
      assert(torch.type(orig) == 'nn.Linear',
         'expected last layer to be fully connected')

      local linear = nn.Linear(orig.weight:size(2), opt.nClasses)
      linear.bias:zero()

      model:remove(#model.modules)
      if opt.deviceId >= 0 then
          model:add(linear:cuda())
      else
          model:add(linear:float())
      end
   end

   -- Set the CUDNN flags
   if opt.deviceId >= 0 and opt.cudnn == 'fastest' then
      cudnn.fastest = true
      cudnn.benchmark = true
   elseif opt.cudnn == 'deterministic' then
      -- Use a deterministic convolution implementation
      model:apply(function(m)
         if m.setMode then m:setMode(1, 1, 1) end
      end)
   end

   -- Wrap the model with DataParallelTable, if using more than one GPU
   if opt.nGPU > 1 then
      local gpus = torch.range(1, opt.nGPU):totable()
      local fastest, benchmark = cudnn.fastest, cudnn.benchmark

      local dpt = nn.DataParallelTable(1, true, true)
         :add(model, gpus)
         :threads(function()
            local cudnn = require 'cudnn'
            cudnn.fastest, cudnn.benchmark = fastest, benchmark
         end)
      dpt.gradInput = nil

      if opt.deviceId >= 0 then
          model = dpt:cuda()
      else
          print 'init: not use cuda'
          model = dpt:float()
      end

   end
   local criterion 

   if opt.deviceId >= 0 then
       criterion = nn.CrossEntropyCriterion():cuda()
   else
       criterion = nn.CrossEntropyCriterion():float()
   end
   return model, criterion
end

return M
