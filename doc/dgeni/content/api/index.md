@ngdoc content
@name The Fl Framework API
@id content.api.main
@isindex
@description

## The Fl Framework API

The API is broken down into a collection of modules, which group together related functionality.
Note, however, that this arrangement is not reflected in the actual code, but rather is defined
as a guide to different types of functionality provided by the framework code.

#### Core functionality

The following module are available:

- {@sref fl.object_system} is the core module for Floopstreet JS code. It includes functions
  and objects for managing class hierarchies and object instantiation:
  - {@sref FlExtensions} contains code to support the mix-in (extension) features
    of classes defined via {@sref FlClassManager#make_class}.
  - {@sref FlClassManager} is used to manage the class hierarchy
    ({@sref FlClassManager#make_class}) and create instances of registered classes
    ({@sref FlClassManager#instance_factory} and {@sref FlClassManager#modelize}).

  The root of the class hierarchy, {@sref FlRoot}, is also defined in this module.

- {@sref fl.model_factory} is the module to manage data model services. These are classes that
  encapsulate a data object returned by (Rails) API calls.
  It includes the following entities:
  - {@sref FlModelBase} is the base class for model services.
  - {@sref FlModelCache} is a service that manages a cache of model instances.
  - {@sref FlModelFactory} is a service that manages creation of model instances from model data.
    It also defines the global model factory service {@sref FlGlobalModelFactory}.
  - {@sref FlGlobalModelFactory} is a globally accessible instance of {@sref FlModelFactory}.

- {@sref fl.api_services} is the module to manage API services. These are classes that
  encapsulate interactions with (Rails) server APIs (typically, Rails resource APIs).
  It includes the following entities:
  - {@sref FlAPIService} is the base class for API services.
  - {@sref FlAPIServiceRegistry} is a registry of API service classes.
  - {@sref FlGlobalAPIServiceRegistry} is a globally accessible instance of {@sref FlAPIServiceRegistry}.
