package com.vasileff.ceylon.vscode.compiler;

import com.redhat.ceylon.common.config.CeylonConfig;
import com.redhat.ceylon.common.config.DefaultToolOptions;
import com.redhat.ceylon.compiler.java.loader.model.LazyModuleSourceMapper;
import com.redhat.ceylon.compiler.typechecker.context.Context;
import com.redhat.ceylon.compiler.typechecker.context.PhasedUnits;
import com.redhat.ceylon.model.loader.model.LazyModuleManager;

public class JavaModuleSourceMapper extends LazyModuleSourceMapper {

    public JavaModuleSourceMapper(Context context, LazyModuleManager moduleManager) {
        super(context, moduleManager);
    }

    @Override
    protected PhasedUnits createPhasedUnits() {
        PhasedUnits units = super.createPhasedUnits();
        String fileEncoding = "UTF-8";
        if (fileEncoding == null) {
            fileEncoding = CeylonConfig.get(DefaultToolOptions.DEFAULTS_ENCODING);
        }
        if (fileEncoding != null) {
            units.setEncoding(fileEncoding);
        }
        return units;
    }
}
