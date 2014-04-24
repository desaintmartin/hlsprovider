package org.mangui.osmf.plugins {
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import org.mangui.HLS.HLSSettings;
    import org.mangui.HLS.utils.Log;
    import org.osmf.media.MediaElement;
    import org.osmf.media.MediaFactoryItem;
    import org.osmf.media.MediaFactoryItemType;
    import org.osmf.media.MediaResourceBase;
    import org.osmf.media.PluginInfo;

    public class HLSPlugin extends PluginInfo {
        public function HLSPlugin(items : Vector.<MediaFactoryItem>=null, elementCreatedNotification : Function = null) {
            items = new Vector.<MediaFactoryItem>();
            items.push(new MediaFactoryItem('org.mangui.osmf.plugins.HLSPlugin', canHandleResource, createMediaElement, MediaFactoryItemType.STANDARD));

            super(items, elementCreatedNotification);
        }

        /**
         * Called from super class when plugin has been initialized with the MediaFactory from which it was loaded.
         * Used for customize HLSSettings with values provided in resource metadata (that was set eg. in flash vars)
         *  
         * @param resource	Provides acces to the resource used to load the plugin and any associated metadata
         * 
         */
        override public function initializePlugin(resource : MediaResourceBase) : void {
            Log.debug("OSMF HLSPlugin init");
            metadataParamsToHLSSettings(resource);
        }

        private function canHandleResource(resource : MediaResourceBase) : Boolean {
            return HLSLoaderBase.canHandle(resource);
        }

        private function createMediaElement() : MediaElement {
            return new HLSLoadFromDocumentElement(null, new HLSLoaderBase());
        }

        private function metadataParamsToHLSSettings(resource : MediaResourceBase) : void {
            if (resource == null) {
                return;
            }

            var metadataNamespaceURLs : Vector.<String> = resource.metadataNamespaceURLs;

            // set all legal params values to HLSSetings properties
            for each (var key : String in metadataNamespaceURLs) {
                var param : String = HLSPluginParams.paramMap[key];
                var typeOfParam : Class;

                if (param) {
                    // try to assign value with proper object type
                    try {
                        var c : Class = getDefinitionByName(getQualifiedClassName(HLSSettings[param])) as Class;
                        // get HLSSetting type
                        HLSSettings[param] = c(resource.getMetadataValue(key));
                        Log.debug("HLSSettings." + param + " = " + HLSSettings[param]);
                    } catch(error : Error) {
                        Log.warn("Can't set HLSSettings." + param);
                    }
                }
            }
        }
    }
}
