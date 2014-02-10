package org.mangui.flowplayer {
   import org.flowplayer.model.Plugin;
   import org.flowplayer.model.PluginModel;
   import org.flowplayer.view.Flowplayer;

    public class HLSPlugin extends HLSProvider implements Plugin {

        private var _model:PluginModel;
        private var _player:Flowplayer;
        
      public function getDefaultConfig():Object {
            return null;
        }
      
        public function onConfig(model:PluginModel):void {
            _model = model;
        }
    
        public function onLoad(player:Flowplayer):void {
            _player = player;
            _model.dispatchOnLoad();
        }
      
      
    }
}

