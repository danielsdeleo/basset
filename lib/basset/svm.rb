require File.dirname(__FILE__) + "/../../../libsvm-ruby-swig/lib/svm"

module Basset
  # =Overview
  # A class for SVM document classification.  Follows the same basic interface
  # as NaiveBayes; add labeled training documents to the classifier, then 
  # use it to classify unlabeled documents.  Do test your accuracy before 
  # using the classifier in production, there are a lot of knobs to tweak.
  # When testing, it is usually best to use a separate set of documents, i.e.,
  # not the training set.
  # =Learning Resources
  # SVM can be tricky to understand at first, try the following references:
  # http://en.wikipedia.org/wiki/Support_vector_machine
  # http://www.igvita.com/2008/01/07/support-vector-machines-svm-in-ruby/
  # http://www.csie.ntu.edu.tw/~cjlin/papers/guide/guide.pdf
  # =Implementation
  # This class wraps libsvm-ruby-swig, which is itself a swig based wrapper for
  # libsvm.
  # libsvm-ruby-swig: http://github.com/tomz/libsvm-ruby-swig
  # libsvm: http://www.csie.ntu.edu.tw/~cjlin/libsvm
  # verbose version:
  # Chih-Chung Chang and Chih-Jen Lin, LIBSVM : a library for support vector machines, 2001. Software available at http://www.csie.ntu.edu.tw/~cjlin/libsvm
  # 
  # There is also the libsvm-ruby implementation.  It was originally available from
  # http://debian.cilibrar.com/debian/pool/main/libs/libsvm-ruby/libsvm-ruby_2.8.4.orig.tar.gz
  # but was not available from there when I last checked.  The Ubuntu package
  # was still available as of this writing.
  class Svm
    #include YamlSerialization
    attr_reader :class_labels, :feature_dictionary
        
    def initialize
      @total_classes = 0
      @feature_dictionary = []
      @class_labels = {}
      @documents_for_class = Hash.new {|docs_hash,key| docs_hash[key] = []}
      @svm_parameter = default_svm_parameter
    end
    
    # Adds a new document to the training set.
    def add_document(classification, feature_vectors)
      update_class_labels_with_new(classification) if new_class?(classification)
      @feature_dictionary += feature_vectors.map { |fv| fv.name }
      @feature_dictionary.uniq!
      @documents_for_class[classification] << feature_vectors.map { |fv| fv.name }
    end
    
    # Gives the vector representation of the training documents of class
    # _classification_
    def vectorized_docs(classification)
      # hardwired to binary representation
      @documents_for_class[classification].map do |features| 
        vectorize_doc(features)
        #@feature_dictionary.map { |dict_feature| features.include?(dict_feature) ? 1 : 0}
      end
    end
    
    # Returns the vectorized representation of the training data, suitable for 
    # use in the constructor for the libsvm Problem class.
    def labels_and_document_vectors
      # {labels => [features1-label, features2-label, ...], :features => [features1, features2, ...]}
      labels_features = {:labels => [], :features => []}
      @class_labels.each do |classification, label|
        vectorized_docs(classification).each do |document_vector|
          labels_features[:labels] << label
          labels_features[:features] << document_vector
        end
      end
      labels_features
    end
    
    def classify(feature_vectors)
      labels_features = labels_and_document_vectors
      prob = Problem.new(labels_features[:labels], labels_features[:features])
      model = Model.new(prob, @svm_parameter)
      predicted_label = model.predict(vectorize_doc(feature_vectors.map { |fv| fv.name }))
      class_of_label(predicted_label)
    end
    
    def classes
      @class_labels.keys
    end
        
    # Exposes the libsvm-ruby-swig Parameter object.  If given 
    # a block, the parameter object is yielded, otherwise,
    # it's returned.
    # 
    # For example, to set parameters to their default values:
    #   
    #   basset_svm_obj.parameters do |param|
    #     param.C = 100           
    #     param.svm_type = NU_SVC
    #     param.degree = 1
    #     param.coef0 = 0
    #     param.eps= 0.001
    #     param.kernel_type = RBF
    #   end
    # 
    # To access one value:
    #   basset_svm_obj.parameters.svm_type
    #   => NU_SVC
    def parameters
      if block_given?
        yield @svm_parameter
      else
        @svm_parameter
      end
    end
    
    private
    
    def new_class?(classification)
      !@class_labels.keys.include?(classification)
    end
    
    def vectorize_doc(features)
      @feature_dictionary.map { |dict_feature| features.include?(dict_feature) ? 1 : 0}
    end
    
    def default_svm_parameter
      param = ::Parameter.new
      param.C = 100
      param.svm_type = NU_SVC
      param.degree = 1
      param.coef0 = 0
      param.eps= 0.001
      param.kernel_type = RBF
      param
    end
    
    def update_class_labels_with_new(classification)
      #@class_labels.each_value { |vector| vector << 0 }
      @class_labels[classification] = @total_classes  #Array.new(@total_classes, 0) << 1
      @total_classes += 1
    end
    
    def class_of_label(label)
      @class_labels.invert[label.to_i]
    end
    
  end
end